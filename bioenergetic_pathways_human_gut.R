#Set working directory that contains the files to be analyzed
#through Session > Set Working Directory

#Being part of an already existing pipeline, this program assumes
#that the working files contain the extension "final_results"
#in their filename

# Uncomment to download packages 
install.packages("dplyr")
install.packages("ggplot2")

# load packages 
library(dplyr)
library(ggplot2)

#Data preparation----
# put every csv of the wd in a list
csv_list <- list.files(pattern = "final_results.csv", full.names=TRUE)
str(csv_list)
class(csv_list)

#read all csvs in the list
my_files <- lapply(csv_list,function(x) {
  y <- read.csv(x, stringsAsFactors= FALSE, header= TRUE, sep= ',')
  # uncomment next line to add a column that stores the file name
  y$filename <- x
  y 
})

# merge to single data frame
my_data <- do.call(rbind, my_files)

head(my_data)

# new df with the total reads for each bioenergetic pathway
pathway_sum_df <- my_data %>% 
  group_by(Pathway, filename) %>% 
  summarise(Reads = sum(Reads)) 

# new df with the percentage *100 of each pathway, in each dataset
pathway_percentage_df <- pathway_sum_df %>% 
  group_by(filename) %>% 
  mutate("Percentage" = (Percentage = (Reads / sum(Reads)) * 100))


# Heatmap----
# The first visualization is a heatmap
# The apporach used needs the data in matrix form

#Install and load reshape package 
#to create a matrix from the data framed data
install.packages("reshape2") 
library(reshape2)

#create matrix from percentage_df
df_to_matrix <- acast(pathway_percentage_df, 
                     filename~Pathway, value.var="Percentage")

#create heatmap directly from the matrix
#matrix_heatmap <- heatmap(df_to_matrix, Rowv=NA, Colv=NA, 
#col = cm.colors(256), scale="column", 
#margins=c(5,10))

#Melt data into a long form
#The conversion is needed to use ggplot2 to create the heatmap
melt_data <- melt(df_to_matrix, 
              varnames = c("filename", "pathway"),
              value.name = "Percentage of Reads")

#Cut out unnecessary part of the filenames
#for visually appealing purposes
melt_data$filename <- sub("./|_final_results.csv", " ",
                          melt_data$filename)

#extract row of percentage to later use as fill in the heatmap
Z <- melt_data$`Percentage of Reads`

#create the heatmap of the bioenergetic pathways percentage
path_heatmap <- ggplot(melt_data, aes(x = pathway,
                              y = filename,
                              fill = Z)) + 
  geom_tile() + 
  scale_fill_gradient(high = "darkred", low = "antiquewhite") +
  labs(fill = "Percentage of Reads", x = "Bioenergetic Pathways")  

plot(path_heatmap)


#Most common species ----
#show the 20 most prevalent species in each dataset

#group my_data by filename
#mostly doing this to leave intact my_data and use my_data2 
#for these analysis
my_data2 <- my_data %>% 
  group_by(filename) 

#show the 20 most prevelent bacteria species through all the csvs
#along with the number of datasets they appear to
#eg E.coli 6 means that the bacteria was present on six of the analyzed datasets
most_common_species <- sort(table(my_data2$Species), decreasing = TRUE)[1:20]
most_common_species

#Uncomment next lines to see
#the most common species without number of datasets they appear to
#mcs_without_nums <- tail(names(sort(table(my_data2$Species))), 20)
#mcs_without_nums

#create a df with the most common species
#to use to create a visualization
mcs_df <- as.data.frame(most_common_species)
mcs_df

#Recreate previous df but with number of appearances 
#expressed as a percentage
#100% is the total number of csvs

total_csvs <- length(csv_list) #find the total number of csvs 
print(total_csvs)

#create the aformentioned df
mcs_df_per <- mcs_df %>% 
  mutate("Percentage" = as.numeric(format(round((Freq / total_csvs) * 100 , 2), 
                               nsmall = 2))) #limit to 2 decimal digits

class(mcs_df_per$Percentage)

head(mcs_df_per)

#plot the 20 most common species (lollipop)
#in regards to their appearance through the analyzed datasets

#Lollipop ----
#create lollipop
top20_lol <- ggplot(mcs_df_per, aes(x = Var1, y = Percentage)) +
  geom_segment(aes(x = Var1, xend = Var1, y = 0, yend = Percentage),
               color = "black", lwd = 2) +
  geom_point(size = 3, pch = 21, bg = "coral3", col = 1) +
  labs(y = "Percentage of datasets the species appeared to", x = "Species") +
  coord_flip() +
  theme_minimal()

plot(top20_lol)


#Top species----
#most prevalent species in each dataset
#along with the number of hits and 
#in regards to its contributing bioenergetic pathway

#indicate the working data
my_data3 <- my_data

#create df that contains the most prevalent species in each dataset
#and the bioenergetic pathway it contributes to
top_species <- my_data3 %>% 
  group_by(filename) %>% 
  top_n(1, Reads)

#Remove unnecessary part of the filenames
#for visually appealing purposes
top_species$filename <- sub("./|_final_results.csv", " ",
                          top_species$filename)

#Bubble plot (reads)----
#bubble plot
top_sp_plot <- ggplot(top_species, aes(x = Species, y = filename)) + 
  geom_point(aes(color = Pathway, size = Reads), alpha = 0.5) +
  #scale_color_manual(values = c("#00AFBB", "#E7B800", "#FC4E07")) +
  scale_size(range = c(5, 20))  # Adjust the range of points size

plot(top_sp_plot)


#Top species (percentage)----
#the same but with percentage of reads to total
sum_of_reads <- my_data3 %>% 
  group_by(filename) %>% 
  summarise("Total_sum" = sum(Reads))

#Remove unnecessary part of the filenames
#a) for visually appealing purposes
#b) so the filenames between the dfs sum_of_reads and top_species
#are the same allowing for a merge under this key
sum_of_reads$filename <- sub("./|_final_results.csv", " ",
                            top_species$filename)

#merge top_species and sum_of_reads
#to later calculate the percentage of reads
final_df <- merge(top_species, sum_of_reads, by = "filename")

#calculate percentage of reads to total reads in each dataset
final_df2 <- final_df %>% 
  group_by(filename) %>% 
  mutate("Percentage" = as.numeric(format(round((Reads / Total_sum) * 100, 2), 
         nsmall = 2)))

class(final_df2$Percentage)


# Bubble plot (percentage)----
#create bubble plot with percentage this time
top_sp_plot2 <- ggplot(final_df2, aes(x = Species, y = filename)) + 
  geom_point(aes(color = Pathway, size = Percentage), alpha = 0.5) +
  #scale_color_manual(values = c("#00AFBB", "#E7B800", "#FC4E07")) +
  scale_size(range = c(5, 20), # Adjust the range of points size
             breaks=c(0,25,50,75,100),
             labels=c("0%","25%","50%","75%","100%")) 
  
plot(top_sp_plot2)

#Save plots ----
#save heatmap
ggsave("bioenergetic_pathways_heatmap.jpeg", plot = path_heatmap, dpi = 300)

#save lollipop of the 20 most common species
ggsave("top20species_lollipop.jpeg", plot = top20_lol, dpi = 300)

#save bubble plot (reads) of the top species in each dataset
ggsave("top1species_bubblechart.jpeg", plot = top_sp_plot, dpi = 300)

#save bubble plot (percentage of reads) of the top species in each dataset
ggsave("top1species_percentage_bubblechart.jpeg", plot = top_sp_plot2, dpi = 300)


