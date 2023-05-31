import json
import time
import subprocess, os
import requests
import logging
import fcntl
import base64
import codecs

db = "anodevpn-server/clients.json"

def read_db():
    global db
    try:
        with open(db) as json_file:
            json_data = json.load(json_file)
            return json_data
    except FileNotFoundError:
        logging.error(f"JSON file not found: {db}")
        print(f"JSON file not found: {db}")
        exit(1)
        

def write_db(json_data):
    global db
    for i in range(5):
        try:
            with open(db, 'w') as json_file:
                try:
                    fcntl.flock(json_file, fcntl.LOCK_EX)
                    json.dump(json_data, json_file)
                    return
                except IOError as e:
                    logging.info("Error writing to clients.json: {}".format(e))
                    time.sleep(0.2)
                finally:
                    fcntl.flock(json_file, fcntl.LOCK_UN)  
        except FileNotFoundError:
            logging.error(f"JSON file not found: {db}")
            print(f"JSON file not found: {db}")
            exit(1)

def decimal_to_hex(decimal):
    return format(decimal, '02x')

def get_hex_from_ip(ip_address):
    # Extract the last two octets of the source IP address
    last_two_parts = ip_address.split('.')[-2:]

    part1 = last_two_parts[0]
    part2 = last_two_parts[1]

    # Convert each part to hexadecimal
    hex_part1 = decimal_to_hex(int(part1))
    hex_part2 = decimal_to_hex(int(part2))

    # Concatenate the hexadecimal parts
    hex_ip = hex_part1 + hex_part2

    return hex_ip

def addPremium(ip):
    lsLimitPaid = "950mbit"
    hex = get_hex_from_ip(ip)
    logging.info("Enable premium for {} from class 1:{}".format(ip,hex))
    cmd = "tc class replace dev tun0 parent 1:fffe classid 1:{} hfsc ls m2 {} ul m2 {}".format(hex, lsLimitPaid, lsLimitPaid)
    try:
        subprocess.check_output(cmd, shell=True).decode('utf-8').rstrip()
        cmd = "nft add element pfi m_client_leases { "+ip+" : \"1:"+hex+"\" }"
        subprocess.check_output(cmd, shell=True).decode('utf-8').rstrip()
    except subprocess.CalledProcessError as e:
        logging.error("Error adding premium: {}".format(e.output))
    
def removePremium(ip):
    lsLimitPaid = "950mbit"
    hex = get_hex_from_ip(ip)
    logging.info("Disable premium for {} from class 1:{}".format(ip,hex))
    cmd = "tc class delete dev tun0 parent 1:fffe classid 1:{} hfsc ls m2 {} ul m2 {}".format(hex, lsLimitPaid, lsLimitPaid)
    try:
        subprocess.check_output(cmd, shell=True).decode('utf-8').rstrip()
        cmd = "nft delete element pfi m_client_leases { "+ip+" : \"1:"+hex+"\" }"
        subprocess.check_output(cmd, shell=True).decode('utf-8').rstrip()
    except subprocess.CalledProcessError as e:
        logging.error("Error removing premium: {}".format(e.output))



def hasDurationEnded(start_time, duration):
    logging.info("Checking if duration has ended with start time {} and duration {}".format(start_time, duration))
    end_time = start_time + (duration*3600)
    current_time = time.time()
    if (current_time > end_time):
        logging.info("Duration has ended")
        return True
    else:
        logging.info("Duration has not ended")
        return False

def getBalance(address):
    logging.info("Getting balance for {}".format(address))
    # Get balance from the PKT blockchain
    url = "http://localhost:8080/api/v1/wallet/address/balances"
    response = requests.post(url, json={"showzerobalance": false}, headers={"Content-Type": "application/json"})
    if response.status_code == 200:
        balances = response.json()
        for addr in balances["addrs"]:
            if addr["address"] == address:
                logging.info("Balance for {} is {}".format(address, addr["total"]))
                return address["total"]
        return None
    else:
        logging.error("Error getting response")
        return None
    
def isValidPayment(address, ip):
    premiumPrice = os.environ.get('PKTEER_PREMIUM_PRICE')
    # Check balance for the address
    balance = getBalance(address)
    if (balance is not None):
        if balance < premiumPrice:
            logging.info("Client paid less than the premium price of {}: {}".format(premiumPrice, address["total"]))
            return False
        elif balance >= premiumPrice:
            logging.info("Client paid the premium price of {}: {}".format(premiumPrice, address["total"]))
            return True
    else:
        logging.info("Payment may not have come throught yet...")
        return False

def bcastTransaction(tx):
    url = "http://localhost:8080/api/v1/neutrino/bcasttransaction"
    hex_data = codecs.encode(base64.b64decode(tx), 'hex')
    utf8_str = codecs.decode(hex_data, 'utf-8')
    enc_data = base64.b64encode(utf8_str.encode('utf-8'))
    b64tx = enc_data.decode('utf-8')
    try:
        logging.info("Broadcasting transaction: {}".format(b64tx))
        response = requests.post(url, json={"tx": b64tx}, headers={"Content-Type": "application/json"})
        if response.status_code == 200:
            json_response = response.json()
            return json_response["txnHash"]
        else:
            logging.error("Error getting response: {}".format(response.status_code))
            return None
    except requests.exceptions.RequestException as e:
        logging.error("Error broadcasting transaction: {}".format(e))
                    
def main():
    logging.basicConfig(filename='premium_handler.log', level=logging.INFO, format='%(asctime)s %(levelname)s: %(message)s')
    waitingTime = 5 * 60 # 5 minutes
    while True:
        # Read the clients.json file
        clients = read_db()
        remainingClients = []
        for client in clients["clients"]:
            remove = False
            # print("Checking client {}".format(client["ip"]))
            # check for clients that have transaction but not txid, means transaction has not been broadcasted,
            # try to broadcast it again, check error and reject client if it fails
            if client["txid"] is None or client["txid"] == "":
                logging.info("Client has transaction but no txid")
                print("Client has transaction but no txid, trying to broadcast it again")
                client["txid"] = bcastTransaction(client["transaction"])
                logging.info("Broadcasted transaction: {} got txid {}".format(client["transaction"], client["txid"]))

            # Check the time for each client
            startTime = client["time"] / 1000 # convert to seconds
            durationEnded = hasDurationEnded(startTime, client["duration"])
            currentTime = time.time()
            valid = isValidPayment(client["address"], client["ip"])
            if durationEnded:
                logging.info("Duration has ended for client {}".format(client["ip"]))
                removePremium(client["ip"])
                remove = True
            elif not valid and (startTime + waitingTime) < currentTime:
                logging.info("Request came at {} but after waiting for {} the payment has not come through yet".format(startTime, waitingTime))
                #print("Request came at {} but after waiting for {} the payment has not come through yet".format(startTime, waitingTime))
                removePremium(client["ip"])
                logging.info("Removed premium for client {}".format(client["ip"]))
                remove = True
            elif valid and not durationEnded:
                logging.info("Add client to premium: {}".format(client["ip"]))
                addPremium(client["ip"])
        
            if not remove:
                remainingClients.append(client)

        clients["clients"] = remainingClients        
        # Remove clients that have duration ended
        write_db(clients)
        time.sleep(10) 

    
if __name__ == "__main__":
    main()