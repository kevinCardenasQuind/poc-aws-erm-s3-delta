# from pyspark.sql import SparkSession
# import sys

# """
#     bucket: s3://emr-data-holamundo
#     con archivos:
#         - products1.csv
#         - products2.csv
#         - products3.csv
    
#         uniremos los archivos en un solo DataFrame y guardaremos el resultado en formato Delta en la carpeta /delta/product_data
# """

# Bucket = "s3://emr-data-holamundo"

# def main():
#     spark = SparkSession.builder.appName("Spark Delta Lake").getOrCreate()

#     # Leer los archivos CSV
#     df1 = spark.read.csv(f"{Bucket}/products1.csv", header=True)
#     df2 = spark.read.csv(f"{Bucket}/products2.csv", header=True)
#     df3 = spark.read.csv(f"{Bucket}/products3.csv", header=True)

#     # Unir los DataFrames
#     df = df1.union(df2).union(df3)

#     # Guardar el DataFrame en un csv en parquet
#     df.write.format("parquet").save(f"{Bucket}/parquet/product_data")

#     spark.stop()


# if __name__ == "__main__":
#     main()

print("Hola Mundo")