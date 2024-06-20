import boto3

# Crear una sesión de boto3
session = boto3.Session(region_name='us-east-1')

# Crear un cliente de EMR
emr_client = session.client('emr')

# Obtener el ID del cluster
with open('cluster_id.txt', 'r') as file:
    cluster_id = file.read().strip()

# Describir el cluster
response = emr_client.describe_cluster(ClusterId=cluster_id)

# Obtener el DNS del master node
master_dns = response['Cluster']['MasterPublicDnsName']
print(f"Master Public DNS: {master_dns}")
