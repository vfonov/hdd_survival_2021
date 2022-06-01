using Downloads


raw_files=[
        # already processed
        #    "https://f001.backblazeb2.com/file/Backblaze-Hard-Drive-Data/data_2013.zip",
        #    "https://f001.backblazeb2.com/file/Backblaze-Hard-Drive-Data/data_2014.zip",
        #    "https://f001.backblazeb2.com/file/Backblaze-Hard-Drive-Data/data_2015.zip",

        #    "https://f001.backblazeb2.com/file/Backblaze-Hard-Drive-Data/data_Q1_2016.zip",
        #    "https://f001.backblazeb2.com/file/Backblaze-Hard-Drive-Data/data_Q2_2016.zip",
        #    "https://f001.backblazeb2.com/file/Backblaze-Hard-Drive-Data/data_Q3_2016.zip",
        #    "https://f001.backblazeb2.com/file/Backblaze-Hard-Drive-Data/data_Q4_2016.zip",

        #    "https://f001.backblazeb2.com/file/Backblaze-Hard-Drive-Data/data_Q1_2017.zip",
        #    "https://f001.backblazeb2.com/file/Backblaze-Hard-Drive-Data/data_Q2_2017.zip",
        #    "https://f001.backblazeb2.com/file/Backblaze-Hard-Drive-Data/data_Q3_2017.zip",
        #    "https://f001.backblazeb2.com/file/Backblaze-Hard-Drive-Data/data_Q4_2017.zip",

        #    "https://f001.backblazeb2.com/file/Backblaze-Hard-Drive-Data/data_Q1_2018.zip",
        #    "https://f001.backblazeb2.com/file/Backblaze-Hard-Drive-Data/data_Q2_2018.zip",
        #    "https://f001.backblazeb2.com/file/Backblaze-Hard-Drive-Data/data_Q3_2018.zip",
        #    "https://f001.backblazeb2.com/file/Backblaze-Hard-Drive-Data/data_Q4_2018.zip",

        #    "https://f001.backblazeb2.com/file/Backblaze-Hard-Drive-Data/data_Q1_2019.zip",
        #    "https://f001.backblazeb2.com/file/Backblaze-Hard-Drive-Data/data_Q2_2019.zip",
        #    "https://f001.backblazeb2.com/file/Backblaze-Hard-Drive-Data/data_Q3_2019.zip",
        #    "https://f001.backblazeb2.com/file/Backblaze-Hard-Drive-Data/data_Q4_2019.zip",
        #    "https://f001.backblazeb2.com/file/Backblaze-Hard-Drive-Data/data_Q1_2020.zip",
        #    "https://f001.backblazeb2.com/file/Backblaze-Hard-Drive-Data/data_Q2_2020.zip",
        #    "https://f001.backblazeb2.com/file/Backblaze-Hard-Drive-Data/data_Q3_2020.zip",
        #    "https://f001.backblazeb2.com/file/Backblaze-Hard-Drive-Data/data_Q4_2020.zip",
        #    "https://f001.backblazeb2.com/file/Backblaze-Hard-Drive-Data/data_Q1_2021.zip",
        #    "https://f001.backblazeb2.com/file/Backblaze-Hard-Drive-Data/data_Q2_2021.zip",
        #    "https://f001.backblazeb2.com/file/Backblaze-Hard-Drive-Data/data_Q3_2021.zip",


           "https://f001.backblazeb2.com/file/Backblaze-Hard-Drive-Data/data_Q4_2021.zip",
           "https://f001.backblazeb2.com/file/Backblaze-Hard-Drive-Data/data_Q1_2022.zip"
]


# download files if not exist yet
for u in raw_files
    loc_file=rsplit(u,"/";limit=2)[2]
    if ! isfile(loc_file)
       println("Downloading: $(loc_file)")
       Downloads.download(u,loc_file)
    end
end
