import argparse
import boto3
from pyspark.sql import SparkSession

def check_s3_file_exists(bucket, key):
    """
    Check if a file exists in S3 bucket.

    :param bucket: Name of the S3 bucket.
    :param key: Key of the file in the S3 bucket.
    :return: True if file exists, else False.
    """
    s3 = boto3.client('s3')
    try:
        s3.head_object(Bucket=bucket, Key=key)
        return True
    except Exception as e:
        print(f"File {key} not found in bucket {bucket}. Error: {str(e)}")
        return False

def process_product_data(input_uris, delta_table_path):
    """
    Reads product data from multiple CSV files, merges the data, and writes it to a Delta table in S3.

    :param input_uris: List of URIs of the product CSV files, such as 's3://bucket-name/path/to/product1.csv'.
    :param delta_table_path: The URI where the Delta table is stored, such as 's3://bucket-name/delta/products'.
    """
    with SparkSession.builder.appName("Process Product Data").config("spark.jars.packages", "io.delta:delta-core_2.12:0.8.0").getOrCreate() as spark:
        # Enable Delta Lake support
        spark.conf.set("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension")
        spark.conf.set("spark.sql.catalog.spark_catalog", "org.apache.spark.sql.delta.catalog.DeltaCatalog")

        # Load the product CSV data from multiple sources
        dataframes = []
        for uri in input_uris:
            bucket, key = uri.replace("s3://", "").split("/", 1)
            if check_s3_file_exists(bucket, key):
                print(f"Reading data from {uri}...")
                df = spark.read.option("header", "true").csv(uri)
                dataframes.append(df)
            else:
                print(f"Skipping {uri} as it does not exist.")

        if not dataframes:
            print("No valid input files found. Exiting.")
            return

        # Union all DataFrames
        print("Unioning DataFrames...")
        products_df = dataframes[0]
        for df in dataframes[1:]:
            products_df = products_df.union(df)

        # Show the merged DataFrame
        print("Showing the merged DataFrame...")
        products_df.show()

        # Write the DataFrame to Delta format in S3
        print(f"Writing the DataFrame to Delta format at {delta_table_path}...")
        products_df.write.format("delta").mode("overwrite").save(delta_table_path)

        # Read and show the data from the Delta table
        print(f"Reading the Delta table from {delta_table_path}...")
        delta_df = spark.read.format("delta").load(delta_table_path)
        print("Showing the Delta DataFrame...")
        delta_df.show()

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('--input_uris', nargs='+', help="The URIs for the product CSV files, like S3 bucket locations.")
    parser.add_argument('--delta_table_path', help="The URI where the Delta table is stored, like an S3 bucket location.")
    args = parser.parse_args()

    process_product_data(args.input_uris, args.delta_table_path)
