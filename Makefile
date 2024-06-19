# Variables
BUCKET_CODE=s3://emr-code-holamundo
BUCKET_LOGS=s3://emr-logs-holamundo
BUCKET_DATA=s3://emr-data-holamundo
REGION=us-east-1
CLUSTER_NAME=emr-holamundo-cluster
LOG_URI=$(BUCKET_LOGS)
RELEASE_LABEL=emr-7.1.0
SERVICE_ROLE=EMR_DefaultRole
INSTANCE_PROFILE=EMR_EC2_DefaultRole
KEY_NAME=emr-ec2
SUBNET_ID=subnet-0198500a07047fd6c
AUTO_SCALING_ROLE=arn:aws:iam::789917738754:role/EMR_AutoScaling_DefaultRole

# Archivo para almacenar el Cluster ID
CLUSTER_ID_FILE=cluster_id.txt

.PHONY: all create-buckets upload-code upload-data create-cluster add-step monitor-cluster clean

all: create-buckets upload-code upload-data create-cluster add-step monitor-cluster

create-buckets:
	aws s3 mb $(BUCKET_CODE)
	aws s3 mb $(BUCKET_LOGS)
	aws s3 mb $(BUCKET_DATA)

upload-code:
	aws s3 cp main.py $(BUCKET_CODE)/

upload-data:
	aws s3 cp data/products/product1.csv $(BUCKET_DATA)/
	aws s3 cp data/products/product2.csv $(BUCKET_DATA)/
	aws s3 cp data/products/product3.csv $(BUCKET_DATA)/

create-cluster:
	@echo "Creating EMR cluster..."
	aws emr create-cluster \
		--name "$(CLUSTER_NAME)" \
		--log-uri "$(LOG_URI)" \
		--release-label "$(RELEASE_LABEL)" \
		--service-role "$(SERVICE_ROLE)" \
		--tags "Project=holamundo" "Team=Data" "Domain=Operations" "CostCenter=141013" \
		--ec2-attributes InstanceProfile=$(INSTANCE_PROFILE),KeyName=$(KEY_NAME),SubnetId=$(SUBNET_ID) \
		--applications Name=Hadoop Name=Spark \
		--instance-groups '[{"InstanceCount":1,"InstanceGroupType":"MASTER","Name":"Master","InstanceType":"m5.xlarge","EbsConfiguration":{"EbsBlockDeviceConfigs":[{"VolumeSpecification":{"VolumeType":"gp2","SizeInGB":32},"VolumesPerInstance":2}]}}]' \
		--auto-scaling-role "$(AUTO_SCALING_ROLE)" \
		--scale-down-behavior "TERMINATE_AT_TASK_COMPLETION" \
		--auto-termination-policy '{"IdleTimeout":10800}' \
		--region "$(REGION)" \
		--query 'ClusterId' --output text | tr -d '"' > $(CLUSTER_ID_FILE)
	@echo "Cluster created with ID: $$(cat $(CLUSTER_ID_FILE))"

add-step:
	@read -p "Enter Cluster ID (or leave empty to use last created): " CLUSTER_ID_INPUT; \
	CLUSTER_ID=$${CLUSTER_ID_INPUT:-$$(cat $(CLUSTER_ID_FILE))}; \
	aws emr add-steps --cluster-id $$CLUSTER_ID --steps Type=Spark,Name="ProcessProductData",ActionOnFailure=TERMINATE_CLUSTER,Args=[--deploy-mode,cluster,--master,yarn,$(BUCKET_CODE)/main.py,--input_uris,s3://emr-data-holamundo/product1.csv,s3://emr-data-holamundo/product2.csv,s3://emr-data-holamundo/product3.csv,--delta_table_path,s3://emr-data-holamundo/delta/products]

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
	rm -f $(CLUSTER_ID_FILE)
