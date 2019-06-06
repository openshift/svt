import yaml

print("starting...")
stream = open("./config/simple_reliability.yaml","r")
y = yaml.load(stream)
print(y['reliability']['appTemplates'][3]['template'])
