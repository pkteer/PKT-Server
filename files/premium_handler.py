import json
import time
import subprocess
import os
import logging
import fcntl
import base64
import codecs
import requests

db = "/server/anodevpn-server/clients.json"


def read_db():
    """Function reading the JSON database file and returning the data as a dictionary"""
    try:
        with open(db, encoding="utf-8") as json_file:
            json_data = json.load(json_file)
            return json_data
    except FileNotFoundError:
        logging.error("JSON file not found: %s",db)
        print("JSON file not found: %s", db)
        exit(1)


def write_db(json_data):
    """Function writing the JSON database file with the given dictionary"""
    for _ in range(5):
        try:
            with open(db, 'w', encoding="utf-8") as json_file:
                try:
                    fcntl.flock(json_file, fcntl.LOCK_EX)
                    json.dump(json_data, json_file)
                    return
                except IOError as error:
                    logging.info("Error writing to clients.json: %s",format(error))
                    time.sleep(0.2)
                finally:
                    fcntl.flock(json_file, fcntl.LOCK_UN)  
        except FileNotFoundError:
            logging.error("JSON file not found: %s", db)
            print("JSON file not found: %s",db)
            exit(1)


def decimal_to_hex(decimal: int) -> str:
    """Function converting a decimal number to hexadecimal"""
    return format(decimal, '02x')


def get_hex_from_ip(ip_address: str) -> str:
    """Function converting last two octets of IP address to hexadecimal"""
    ip_part = ip_address.split('.')[1]
    # Concatenate the hexadecimal parts
    hex_ip = hex(int(ip_part))[2:]

    return hex_ip


def add_premium(ip: str):
    """Function adding premium for the given IP address"""
    lsLimitPaid = "950mbit"
    hex_str = get_hex_from_ip(ip)
    logging.info("Enable premium for %s from class 1:%s", ip, hex_str)
    cmd = "tc class show dev tun0 classid 1:{}".format(hex_str)
    try:
        # check if class exists
        output = subprocess.check_output(cmd, shell=True, stderr=subprocess.STDOUT).decode('utf-8').rstrip()
        # logging.info("%s: %s", cmd, output)
        if (output != ""):
            cmd = "tc class replace dev tun0 parent 1:fffe classid 1:{} hfsc ls m2 {} ul m2 {}".format(hex_str, lsLimitPaid, lsLimitPaid)
        else:
            cmd = "tc class add dev tun0 parent 1:fffe classid 1:{} hfsc ls m2 {} ul m2 {}".format(hex_str, lsLimitPaid, lsLimitPaid)
        # Add or replace rule on classid
        output = subprocess.check_output(cmd, shell=True, stderr=subprocess.STDOUT).decode('utf-8').rstrip()
        # logging.info("%s: %s", cmd, output)
        # Check if m_client_leases exists for this IP
        cmd = "nft -j list map ip pfi m_client_leases | jq"
        output = subprocess.check_output(cmd, shell=True, stderr=subprocess.STDOUT).decode('utf-8').rstrip()
        # logging.info("%s: %s", cmd, output)
        json_data = json.loads(output)
        if "map" in json_data and "elem" in json_data["map"]:
            for elem in json_data["map"]["elem"]:
                if elem[0] == ip:
                    # logging.info("m_client_leases already exists for %s, will delete", ip)
                    cmd = "nft delete element pfi m_client_leases { "+ip+" }"
                    output = subprocess.check_output(cmd, shell=True, stderr=subprocess.STDOUT).decode('utf-8').rstrip() 
                    # logging.info("%s: %s", cmd, output)
        cmd = "nft add element pfi m_client_leases { "+ip+" : \"1:"+hex_str+"\" }"
        output = subprocess.check_output(cmd, shell=True, stderr=subprocess.STDOUT).decode('utf-8').rstrip()
        # logging.info("%s: %s", cmd, output)
    except subprocess.CalledProcessError as error:
        logging.error("Error adding premium: %s", error.output)
    

def remove_premium(ip: str):
    """Function removing premium for the given IP address"""
    lsLimitPaid = "950mbit"
    hex_str = get_hex_from_ip(ip)
    logging.info("Disable premium for %s from class 1:%s", ip, hex_str)
    cmd = "tc class delete dev tun0 parent 1:fffe classid 1:{} hfsc ls m2 {} ul m2 {}".format(hex_str, lsLimitPaid, lsLimitPaid)
    try:
        output = subprocess.check_output(cmd, shell=True, stderr=subprocess.STDOUT).decode('utf-8').rstrip()
        # logging.info("%s: %s", cmd, output)
        cmd = "nft delete element pfi m_client_leases { "+ip+" }"
        output = subprocess.check_output(cmd, shell=True, stderr=subprocess.STDOUT).decode('utf-8').rstrip()
        # logging.info("%s: %s", cmd, output)
    except subprocess.CalledProcessError as error:
        logging.error("Error removing premium: %s", error.output)



def has_duration_ended(start_time: int, duration: int) -> bool:
    """Function checking if the duration has ended"""
    try:
        logging.info("Checking if duration has ended with start time %d and duration %d", start_time, duration)
        end_time = start_time + (duration*3600)
        current_time = time.time()
        if (current_time > end_time):
            logging.info("Duration has ended")
            return True
        else:
            logging.info("Duration has not ended")
            return False
    except Exception as error:
        logging.error("Error checking if duration has ended: %s", error)
        return False


def get_balance(address: str) -> int:
    """Function getting the balance for the given address"""
    try:
        logging.info("Getting balance for %s", address)
        # Get balance from the PKT blockchain
        url = "http://localhost:8080/api/v1/wallet/address/balances"
        response = requests.post(url, json={"showzerobalance": True}, headers={"Content-Type": "application/json"}, timeout=5)
        if response.status_code == 200:
            balances = response.json()
            for addr in balances["addrs"]:
                if addr["address"] == address:
                    logging.info("Balance for %s is %d", address, addr["total"])
                    return addr["total"]
            return 0
        else:
            logging.error("Error getting response")
            return 0
    except Exception as error:
        logging.error("Error getting balance: %s", error)
        return 0
            


def is_valid_payment(address: str) -> bool:
    """Function checking if the payment is valid"""
    try:
        with open('/data/env/vpnprice', 'r') as f:
            premium_price = int(f.readline().strip())

        # Check balance for the address
        balance = get_balance(address)
        if (balance != 0):
            if balance < premium_price:
                logging.info("Client paid %d, less than the premium price of %d", balance, premium_price)
                return False
            elif balance >= premium_price:
                logging.info("Client paid the correct premium price of %d", premium_price)
                return True
        else:
            logging.info("Payment may not have come through yet...")
            return False
    except Exception as error:
        logging.error("Error checking for valid payment: %s", error)
        return False
    return False


def bcast_transaction(tx: str) -> str:
    """Function broadcasting the transaction to the PKT blockchain"""
    url = "http://localhost:8080/api/v1/neutrino/bcasttransaction"
    hex_data = codecs.encode(base64.b64decode(tx), 'hex')
    utf8_str = codecs.decode(hex_data, 'utf-8')
    enc_data = base64.b64encode(utf8_str.encode('utf-8'))
    b64tx = enc_data.decode('utf-8')
    try:
        logging.info("Broadcasting transaction: %s", b64tx)
        response = requests.post(url, json={"tx": b64tx}, headers={"Content-Type": "application/json"}, timeout=30)
        if response.status_code == 200:
            json_response = response.json()
            return json_response["txnHash"]
        else:
            logging.error("Error getting response: %d", response.status_code)
            return ""
    except requests.exceptions.RequestException as error:
        logging.error("Error broadcasting transaction: %s", error)
        return ""


def main():
    """Main function"""
    logging.basicConfig(filename='/server/premium_handler.log', level=logging.INFO, format='%(asctime)s %(levelname)s: %(message)s')
    waiting_time = 5 * 60 # 5 minutes
    while True:
        # Read the clients.json file
        clients = read_db()
        remaining_clients = []
        for client in clients["clients"]:
            remove = False
            # print("Checking client {}".format(client["ip"]))
            # check for clients that have transaction but not txid, means transaction has not been broadcasted,
            # try to broadcast it again, check error and reject client if it fails
            if client["txid"] is None or client["txid"] == "":
                logging.info("Client has transaction but no txid")
                print("Client has transaction but no txid, trying to broadcast it again")
                client["txid"] = bcast_transaction(client["transaction"])
                logging.info("Broadcasted transaction: %s got txid %s", client["transaction"], client["txid"])

            # Check the time for each client
            start_time: int= client["time"] / 1000 # convert to seconds
            duration_ended: bool= has_duration_ended(start_time, int(client["duration"]))
            current_time = time.time()
            valid = is_valid_payment(client["address"])
            if duration_ended:
                logging.info("Duration has ended for client %s", client["ip"])
                remove_premium(client["ip"])
                remove = True
            elif not valid and (start_time + waiting_time) < current_time:
                logging.info("Request came at %d but after waiting for %d the payment has not come through yet", start_time, waiting_time)
                remove_premium(client["ip"])
                logging.info("Removed premium for client %s", client["ip"])
                remove = True
            elif valid and not duration_ended:
                logging.info("Add client to premium: %s", client["ip"])
                add_premium(client["ip"])

            if not remove:
                remaining_clients.append(client)

        clients["clients"] = remaining_clients        
        # Remove clients that have duration ended
        write_db(clients)
        time.sleep(10)


if __name__ == "__main__":
    main()