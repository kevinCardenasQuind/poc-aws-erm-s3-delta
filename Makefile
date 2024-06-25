# Variables
BUCKET_CODE=s3://emr-code-holamundo
BUCKET_LOGS=s3://emr-logs-holamundo
BUCKET_DATA=s3://emr-data-holamundo
BUCKET_OUTPUT=s3://emr-output-holamundo
REGION=us-east-1
CLUSTER_NAME=emr-holamundo-cluster
LOG_URI=$(BUCKET_LOGS)
RELEASE_LABEL=emr-7.1.0
SERVICE_ROLE=arn:aws:iam::789917738754:role/EMRFullAccessRole
INSTANCE_PROFILE=EMR_EC2_DefaultRole
KEY_NAME=emr-ec2
SUBNET_ID=subnet-00bd9b19cc18e3c40
AUTO_SCALING_ROLE=arn:aws:iam::789917738754:role/EMR_AutoScaling_DefaultRole

# Archivo para almacenar el Cluster ID
CLUSTER_ID_FILE=cluster_id.txt

# Archivo del script de bootstrap
BOOTSTRAP_SCRIPT=install-jupyter.sh
BOOTSTRAP_S3_PATH=$(BUCKET_CODE)/bootstrap-actions/$(BOOTSTRAP_SCRIPT)

.PHONY: all create-buckets upload-code upload-data upload-bootstrap create-cluster add-step monitor-cluster clean

all: create-buckets upload-code upload-data upload-bootstrap create-cluster add-step monitor-cluster

create-buckets:
	aws s3 mb $(BUCKET_CODE)
	aws s3 mb $(BUCKET_LOGS)
	aws s3 mb $(BUCKET_DATA)
	aws s3 mb $(BUCKET_OUTPUT)

upload-code:
	aws s3 cp main.py $(BUCKET_CODE)/

upload-data:
	aws s3 cp data/products/product1.csv $(BUCKET_DATA)/
	aws s3 cp data/products/product2.csv $(BUCKET_DATA)/
	aws s3 cp data/products/product3.csv $(BUCKET_DATA)/

upload-bootstrap:
	aws s3 cp $(BOOTSTRAP_SCRIPT) $(BOOTSTRAP_S3_PATH)

create-cluster:
	@echo "Creating EMR cluster..."
	aws emr create-cluster \
		--name "$(CLUSTER_NAME)" \
		--log-uri "$(LOG_URI)" \
		--release-label "$(RELEASE_LABEL)" \
		--service-role "$(SERVICE_ROLE)" \
		--unhealthy-node-replacement \
    	--tags "Project=holamundo" "Team=Data" "Domain=Operations" "CostCenter=141013" \
		--ec2-attributes '{"InstanceProfile":"$(INSTANCE_PROFILE)","EmrManagedMasterSecurityGroup":"sg-0384e76fa9579f05c","EmrManagedSlaveSecurityGroup":"sg-0e9bd1960cb8f98be","KeyName":"$(KEY_NAME)","AdditionalMasterSecurityGroups":[],"AdditionalSlaveSecurityGroups":[],"ServiceAccessSecurityGroup":"sg-0c9c4c15e95544efd","SubnetId":"$(SUBNET_ID)"}' \
 		--applications Name=AmazonCloudWatchAgent Name=Hadoop Name=Hive Name=JupyterEnterpriseGateway Name=Livy Name=Spark \
		--configurations '[{"Classification":"spark-hive-site","Properties":{"hive.metastore.client.factory.class":"com.amazonaws.glue.catalog.metastore.AWSGlueDataCatalogHiveClientFactory"}}]' \
		--instance-groups '[{"InstanceCount":1,"InstanceGroupType":"MASTER","Name":"Principal","InstanceType":"m5.xlarge","EbsConfiguration":{"EbsBlockDeviceConfigs":[{"VolumeSpecification":{"VolumeType":"gp2","SizeInGB":32},"VolumesPerInstance":2}]}},{"InstanceCount":1,"InstanceGroupType":"CORE","Name":"Central","InstanceType":"m5.xlarge","EbsConfiguration":{"EbsBlockDeviceConfigs":[{"VolumeSpecification":{"VolumeType":"gp2","SizeInGB":32},"VolumesPerInstance":2}]}},{"InstanceCount":1,"InstanceGroupType":"TASK","Name":"Tarea - 1","InstanceType":"m5.xlarge","EbsConfiguration":{"EbsBlockDeviceConfigs":[{"VolumeSpecification":{"VolumeType":"gp2","SizeInGB":32},"VolumesPerInstance":2}]}}]' \
		--auto-scaling-role "$(AUTO_SCALING_ROLE)" \
		--scale-down-behavior "TERMINATE_AT_TASK_COMPLETION" \
		--region "$(REGION)" \
		--bootstrap-actions '[{"Path":"$(BOOTSTRAP_S3_PATH)"}]' \
		--query 'ClusterId' --output text | tr -d '"' > $(CLUSTER_ID_FILE)
	@echo "Cluster created with ID: $$(cat $(CLUSTER_ID_FILE))"

add-step:
	@read -p "Enter Cluster ID (or leave empty to use last created): " CLUSTER_ID_INPUT; \
	CLUSTER_ID=$${CLUSTER_ID_INPUT:-$$(cat $(CLUSTER_ID_FILE))}; \
	FILE_EXISTS=$$(aws s3 ls $(BUCKET_CODE)/main.py); \
	if [ -z "$$FILE_EXISTS" ]; then \
		echo "Error: main.py not found in $(BUCKET_CODE). Exiting..."; \
		exit 1; \
	fi; \
	aws emr add-steps --cluster-id $$CLUSTER_ID --steps Type=Spark,Name="ProcessProductData",ActionOnFailure=CONTINUE,Args=["--deploy-mode","cluster","--master","yarn","s3://emr-code-holamundo/main.py","s3://emr-data-holamundo/","s3://emr-output-holamundo/"]

monitor-cluster:
	@read -p "Enter Cluster ID (or leave empty to use last created): " CLUSTER_ID_INPUT; \
	CLUSTER_ID=$${CLUSTER_ID_INPUT:-$$(cat $(CLUSTER_ID_FILE))}; \
	while true; do \
		STATE=$$(aws emr describe-cluster --cluster-id $$CLUSTER_ID --query "Cluster.Status.State" --output text); \
		if [ "$$STATE" == "WAITING" ] || [ "$$STATE" == "TERMINATED" ] || [ "$$STATE" == "TERMINATED_WITH_ERRORS" ]; then \
			echo "Cluster state: $$STATE"; \
			break; \
		else \
			echo "Cluster state: $$STATE. Waiting..."; \
			sleep 60; \
		fi; \
	done

clean:
	aws s3 rb $(BUCKET_CODE) --force
	aws s3 rb $(BUCKET_LOGS) --force
	aws s3 rb $(BUCKET_DATA) --force
	aws s3 rb $(BUCKET_OUTPUT) --force
	rm -f $(CLUSTER_ID_FILE)
