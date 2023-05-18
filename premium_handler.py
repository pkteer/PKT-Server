import json
db = "db_clients.json"

def read_db():
    global db
    try:
        with open(db) as json_file:
            json_data = json.load(json_file)
            return json_data
    except FileNotFoundError:
        print(f"JSON file not found: {db}")
        exit(1)
        
def write_json(json_data):
    global db
    with open('w') as json_file:
        json.dump(json_data, json_file)
        
def insert_client(ip, address, start_time, end_time, paid, json_data):
    client = {
        "ip": ip,
        "address": address,
        "start_time": start_time,
        "end_time": end_time,
        "paid": paid
    }
    json_data["clients"].append(client)
    return json_data

def retrieve_address(ip, json_data):
    for client in json_data["clients"]:
        if client["ip"] == ip:
            return client["address"]
    return None

def main():
    # Check PKT Address balance for a fixed amount
    # update the clients.json file
    # if balance is not enough, return error
    # if balance is enough, return success
    return
    
if __name__ == "__main__":
    main()