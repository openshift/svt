import yaml

print("starting...")
stream = open("./config/simple_reliability.yaml","r")
y = yaml.safe_load(stream)
print(y['reliability']['appTemplates'][3]['template'])
