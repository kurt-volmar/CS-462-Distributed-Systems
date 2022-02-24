import requests
import time

def get_children(parent_eci):
    url = f"http://localhost:3000/sky/cloud/{parent_eci}/manage_sensors/sensors"
    sensors_req = requests.get(url)
    return sensors_req.json()


def create_child(parent_eci, child_name):
    url = f"http://localhost:3000/sky/event/{parent_eci}/none/sensor/new?name={child_name}"
    requests.post(url)


def delete_child(parent_eci, child_name):
    url = f"http://localhost:3000/sky/event/{parent_eci}/none/sensor/unneeded_sensor?name={child_name}"
    requests.post(url)

def delete_all_children(parent_eci, sensor_names):
    for name in sensor_names:
        delete_child(parent_eci, name)

def get_temperatures(parent_eci):
    url = f"http://localhost:3000/sky/cloud/{parent_eci}/manage_sensors/all_temperatures"
    temp_req = requests.get(url)
    return temp_req.json()


PARENT_ECI = "ckywg5xtz005o1ntxgugpgokl"

# Delete All Children
delete_all_children(PARENT_ECI, get_children(PARENT_ECI).keys())

# Create Three Children
print(f"Create child A:")
create_child(PARENT_ECI, "A")
time.sleep(0.5)
print(f"Current Children: {get_children(PARENT_ECI).keys()}")

print(f"Create child B:")
create_child(PARENT_ECI, "B")
time.sleep(0.5)
print(f"Current Children: {get_children(PARENT_ECI).keys()}")

print(f"Create child C")
create_child(PARENT_ECI, "C")
time.sleep(0.5)
print(f"Current Children: {get_children(PARENT_ECI).keys()}")

# Delete One Child
print(f"Delete child A")
delete_child(PARENT_ECI, "A")
time.sleep(0.5)
print(f"Current Children: {get_children(PARENT_ECI).keys()}")

# Test Temperatures
print(f"Get All Child Temperatures:")
before_temperatures = get_temperatures(PARENT_ECI)
print(before_temperatures)
print(f"Before:")
print(f"\t{len(before_temperatures['B']) if before_temperatures['B'] is not None else None} readings")
print(f"\t{len(before_temperatures['C']) if before_temperatures['C'] is not None else None} readings")
print("Wait 10 seconds")
time.sleep(10)
after_temperatures = get_temperatures(PARENT_ECI)
print(f"After:")
print(f"\t{len(after_temperatures['B'])} readings")
print(f"\t{len(after_temperatures['C'])} readings")


