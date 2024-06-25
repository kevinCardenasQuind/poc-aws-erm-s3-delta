import sys
from pyspark.sql import SparkSession

def main(input_uris, output_uri):
    spark = SparkSession.builder.appName("ProcessProductData").getOrCreate()

    # Leer los archivos de entrada desde S3
    df1 = spark.read.csv(input_uris[0], header=True, inferSchema=True)
    df2 = spark.read.csv(input_uris[1], header=True, inferSchema=True)
    df3 = spark.read.csv(input_uris[2], header=True, inferSchema=True)

    # Unir los DataFrames
    combined_df = df1.union(df2).union(df3)

    # Escribir el DataFrame combinado en la carpeta de salida en S3
    combined_df.write.csv(output_uri, header=True, mode='overwrite')

    spark.stop()

if __name__ == "__main__":
    input_uris = sys.argv[1:4]
    output_uri = sys.argv[4]
    main(input_uris, output_uri)