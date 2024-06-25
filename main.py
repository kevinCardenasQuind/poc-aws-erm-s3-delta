import sys
from pyspark.sql import SparkSession

def main(input_uris, output_uri):
    spark = SparkSession.builder.appName("ProcessProductData").getOrCreate()

    # Leer los archivos de entrada desde S3
    df = spark.read.csv(input_uris, header=True, inferSchema=True)

    # Escribir el DataFrame combinado en la carpeta de salida en S3
    df.write.csv(output_uri, header=True, mode='overwrite')

    spark.stop()

if __name__ == "__main__":
    input_uris = sys.argv[1:-1]
    output_uri = sys.argv[-1]
    main(input_uris, output_uri)
