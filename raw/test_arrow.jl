using CSV,Arrow,DataFrames


df=CSV.read("data_Q1_2018/2018-02-09.csv",DataFrame)

println(names(df))

Arrow.write("arrow/2018-02-09.arrow",df;compress=:zstd)

