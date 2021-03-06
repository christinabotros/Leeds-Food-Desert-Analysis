---
title: "Leeds Food Deserts"
author: "Christina Botros"
date: "11/01/2021"
output: html_document
---

```{r setup, echo=TRUE, message = FALSE, warning= FALSE}
# Library packages which will be used to run the SIM and analysis 
library(sp)
library(reshape2)
library(geojsonio)
library(rgdal)
library(downloader)
library(maptools)
library(dplyr)
library(broom) 
library(stplanr)
library(ggplot2)
library(MASS)
library(sf)
library(tmap)
library(tmaptools)
library(stringr)
library(ggplot2)
library(leaflet)
library(tidyverse)
library(here)
library(downloader)
library(readxl)
library(janitor)
library(osrm)
```

```{r Boundary files,  echo=TRUE, message = FALSE, warning= FALSE}

boundary <- "https://borders.ukdataservice.ac.uk/ukborders/servlet/download/dynamic/18ADA69EE3F52E511F1610347472851733/16103474735097369146759607396881/BoundaryData.zip" 
#download from the URL
download(boundary, dest="dataset.zip", mode="wb")
#unzip into a new directory called data
unzip("dataset.zip",exdir="./Data")
#get the file names from within the zip file
filename <- list.files("./Data")
#in order to read the OA boundary please clone/download the BoundaryData folder from the github repro - everything else is accessible via https links
here::here()
OA <- st_read(here::here("Data", "england_oac_2011.shp")) %>%
  st_transform(27700)

OA %>%
  st_geometry() %>%
  plot() 

# Collapsed OAs to a single boundary of Leeds
Leeds <- OA %>%
  group_by(code) 

Leeds1 <- Leeds %>%
  st_union() %>% 
  plot()

```

```{r Population Dataset,   echo=TRUE, message = FALSE, warning= FALSE}
#Reading in mid-year population estimates from ONS.
url_oa_pop_zip <- "https://www.ons.gov.uk/file?uri=%2fpeoplepopulationandcommunity%2fpopulationandmigration%2fpopulationestimates%2fdatasets%2fcensusoutputareaestimatesintheyorkshireandthehumberregionofengland%2fmid2019sape22dt10c/sape22dt10cmid2019yorkshireandthehumber.zip"
#download from the URL
download(url_oa_pop_zip, dest="dataset.zip", mode="wb")
#unzip into a new directory called data
unzip("dataset.zip",exdir="./Data")
#get the file names from within the zip file
filename <- list.files("./Data")
#read the sheet you want from the file
oa_pop <- read_xlsx(here::here("Data", "SAPE22DT10c-mid-2019-coa-unformatted-syoa-estimates-yorkshire-and-the-humber.xlsx"), sheet="Mid-2019 Persons", skip = 3, col_names = T)
oa_pop <- clean_names(oa_pop)

head(oa_pop)
```

```{r Population merge to just Leeds,   echo=TRUE, message = FALSE, warning= FALSE}
#join this population to the OA boundary data

#keep columns we want
oa_pop <- oa_pop[,1:3]
#rename columns
colnames(oa_pop)[3] <- "TotalPop"
#join to spatial data

oa_map <- OA %>%
  merge(., 
        oa_pop, 
        by.x = "code", 
        by.y = "oa11cd")

OA <- merge(OA, 
            oa_pop, 
            by.x = "code", 
            by.y = "oa11cd")

#make a very quick map of population by OA

# qtm(oa_map, 
#     fill = "TotalPop")
# 
# tmap_mode("plot")
# qtm(oa_map, 
#     fill = "oac_supe_1")

OAC_map <- tm_shape(Leeds) + tm_borders(col="black", alpha=NA) + 
  tm_shape(OA) + tm_borders(col="light grey", alpha=0.1) + 
  tm_fill(col="oac_supe_1", palette = "Set2", alpha = 1,breaks = c(1,2,3,4,5,6,7,8), title = "Output Area Classification")
OAC_map

tmap_save(OAC_map, "OAC map.png")
```

```{r Geolytix Retail Points Dataset,   echo=TRUE, message = FALSE, warning= FALSE}
# previous years grocery points available from here <- "https://drive.google.com/file/d/1B8M7m86rQg2sx2TsHhFa2d-x-dZ1DbSy/view?usp=sharing"


retail_points <- read.csv("https://raw.githubusercontent.com/christinabotros/Leeds-Food-Desert-Analysis/main/geolytix_retailpoints_v17_202008.csv")   
head(retail_points)
plot(retail_points$bng_e, retail_points$bng_n)

retail_sf <- st_as_sf(retail_points, coords = c("bng_e", "bng_n"), 
                      crs = 27700)

# Clip the retail points to only be for those in Leeds
retail_leeds <- retail_sf[oa_map,]


retailers_map <- tm_shape(oa_map$geometry) + 
  tm_polygons(col="white", alpha = 0.3) + 
  tm_shape(retail_leeds) + 
  tm_symbols(col ="red", scale =.3)
retailers_map

retail_leeds <- retail_leeds %>% rename('Grocery Retailers' = retailer)

finalmap <- tm_shape(Leeds1) + tm_borders(col="black") +
  tm_shape(oa_map$geometry) + tm_borders(col="light grey", alpha=0.1) +
  tm_shape(retail_leeds) + tm_symbols(col="Grocery Retailers", scale = 0.5, palette = "Accent") 
finalmap

tmap_save(finalmap, "grocery retailers.png")

#write.csv(retail_leeds, "retail_leeds.csv")

# unique names of the retailers

retailers <- unique(retail_leeds$retailer.x)

# [1] "Aldi"                   "Asda"                  
# [3] "Marks and Spencer"      "Morrisons"             
# [5] "Sainsburys"             "Tesco"                 
# [7] "Waitrose"               "Lidl"                  
# [9] "Costco"                 "Makro"                 
# [11] "The Co-operative Group" "Iceland"               
# [13] "Farmfoods"              "Heron"                 
# [15] "Jack Fultons"           "Spar

```

```{r OA Expenditure Calculations,   echo=TRUE, message = FALSE, warning= FALSE}
#reading in ONS expenditure dataset [Oi]
ons_exp <- read.csv("https://raw.githubusercontent.com/christinabotros/Leeds-Food-Desert-Analysis/main/weekly%20household%20expenditure.csv")

# need to work out the average spend on groceries against OA 
ons_exp[9,5:12]
ons_exp[23, 5:12]

ons_exp1 <- ons_exp[23,c(5:12)]
colnames(ons_exp1)[1] <- ("1")
colnames(ons_exp1)[2] <- ("2")
colnames(ons_exp1)[3] <- ("3")
colnames(ons_exp1)[4] <- ("4")
colnames(ons_exp1)[5] <- ("5")
colnames(ons_exp1)[6] <- ("6")
colnames(ons_exp1)[7] <- ("7")
colnames(ons_exp1)[8] <- ("8")

oa_map['grp_exp'] <- NA
oa_map$grp_exp[(oa_map$oac_sub__1 == "1")] = ons_exp1[1,1]

oa_map$grp_exp[oa_map$oac_supe_1 == "1"] <- as.numeric(ons_exp1[1,1])
oa_map$grp_exp[oa_map$oac_supe_1 == "2"] <- as.numeric(ons_exp1[1,2])
oa_map$grp_exp[oa_map$oac_supe_1 == "3"] <- as.numeric(ons_exp1[1,3])
oa_map$grp_exp[oa_map$oac_supe_1 == "4"] <- as.numeric(ons_exp1[1,4])
oa_map$grp_exp[oa_map$oac_supe_1 == "5"] <- as.numeric(ons_exp1[1,5])
oa_map$grp_exp[oa_map$oac_supe_1 == "6"] <- as.numeric(ons_exp1[1,6])
oa_map$grp_exp[oa_map$oac_supe_1 == "7"] <- as.numeric(ons_exp1[1,7])
oa_map$grp_exp[oa_map$oac_supe_1 == "8"] <- as.numeric(ons_exp1[1,8])

# now we multiple the total population by the expenditure in that supergroup
oa_map['expenditure'] <- NA

oa_map$grp_exp <- as.numeric(as.character(unlist(oa_map$grp_exp)))
class(oa_map$grp_exp)
class(oa_map$TotalPop)

oa_map$expenditure <- (oa_map$grp_exp) * (oa_map$TotalPop)

```

```{r Distance Matrix between Origins and Destinations,   echo=TRUE, message = FALSE, warning= FALSE}

oa_map$centroids <- st_centroid(oa_map$geometry)

#check if we have received the centroids
centroids_map <- tm_shape(oa_map$geometry) + tm_polygons(col="white") + tm_shape(oa_map$centroids) + tm_symbols(col="red", scale =.3)
centroids_map

retail_leeds_pts <- st_centroid(retail_leeds)
retail_leeds_pts <- retail_leeds_pts[,1]
qtm(retail_leeds_pts)
oa_leeds_pts <- st_centroid(OA)
oa_leeds_pts <- oa_leeds_pts[,1] %>% rename(., id = code)
#qtm(oa_leeds_pts)


### Calculate distance matrix [Cij

#create a vector of all origin and destination points
all_od_pts <- rbind(oa_leeds_pts, retail_leeds_pts)
plot(all_od_pts)
summary(all_od_pts)

#create some vectors of the IDs
OA_Origin_codes <- OA$code #vector of all OA code names for your origins (that you can link back to the point geometries)
destination_shops <- retail_leeds$id #vector of codes for your shops (that you can link back to your shop point data)

#this should create a square(ish) matrix from the list of origin and destination codes
tb <- as_tibble(matrix(nrow = length(OA_Origin_codes), ncol = length(destination_shops), dimnames = (list(OA_Origin_codes,destination_shops))))

#OK, this is a proper mess, but it works - can be tidied afterwards. 
#The idea is to get the rownames to the left of the matrix. Can definitely 
#do with in one step with relocate in dplyr, but here we go...
#create a new column to store the row (origin) names
tb <- tb %>% 
  mutate(row_name = OA_Origin_codes) %>% 
  #and then turn this column into some actual 'row names' i.e. not a real column but names for the rows
  column_to_rownames(var = "row_name")

#now because I couldn't do it in one step, now create a new column from rownames
tb_1 <- tb %>% rownames_to_column(var = "orig")

#now pivot this longer into a new paired-list of origins and destinations
tb_long <- pivot_longer(tb_1, cols = 2:ncol(tb_1), names_to = "dest")
tb_long$value <- 1

#now generate some staight-line flow lines. We could try and route these along roads
#but given how many, this would totally break your computer. Start easy. 
travel_lines <- od2line(flow = tb_long, zones = all_od_pts, origin_code = "orig", dest_code = "dest")
travel_lines

#test to see if it's worked - don't try and plot the whole thing or R will cry!
#sub <- travel_lines[1:10000,]
#tmap_mode("view")
#qtm(sub)

#now calculate some distances
distance_matrix <- geo_length(travel_lines)
#now attach this back to travel_lines
travel_lines$dist <- distance_matrix

```

```{r Distances < 500m,   echo=TRUE, message = FALSE, warning= FALSE}

#create a subset of all connections less than 500m
sub_distance500m <- filter(travel_lines, dist < 500)

sub_distance500m <- sub_distance500m %>% rename('Distance from OA to grocery store' = dist)

#plot these by distance just to have a look
tmap_mode("plot")
lines_map <- tm_shape(Leeds1) + tm_borders(col="black") + tm_shape(oa_map$geometry) + tm_borders(col="light grey", alpha=0.1) +
  tm_shape(sub_distance500m) +
  tm_lines(palette = "plasma",
           breaks = c(0, 50, 100, 150, 200, 250, 300, 350, 400, 450, 500),
           lwd = "Distance from OA to grocery store",
           alpha = 0.5,
           col = "Distance from OA to grocery store") +
  tm_layout(legend.outside = TRUE)

# oa_500m$orig <- unique(sub_distance500m$orig)
# oa_500m$provision <- 1
# 
# provision_at_500m <- oa_map %>%
#   merge(., 
#         oa_500m, 
#         by.x = "code", 
#         by.y = "orig")
# 
# oa_covered <- tm_shape(Leeds1) + tm_borders(col="black") + 
#   tm_shape(oa_map$geometry) + tm_fill(NA, alpha = 0.2) + 
#   tm_borders(col="lightgrey", alpha=0.1) + 
#   tm_shape(provision_at_500m) + tm_fill(col ="provision", palette ="darkgrey", alpha = 0.6) +
#   tm_legend(legend.show = FALSE) 

# provision_500 <-  tm_shape(sub_distance500m) +
#   tm_lines(palette = "plasma",
#            breaks = c(0, 50, 100, 150, 200, 250, 300, 350, 400, 450, 500),
#            lwd = "dist",
#            alpha = 1,
#            col = "dist") +
#   tm_legend(legend.show = TRUE)
# 
# final_500_provision <- oa_covered + provision_500
# final_500_provision

tmap_save(lines_map, "500m provision.png")
```

```{r Retailers floorspace from GMAP,   echo=TRUE, message = FALSE, warning= FALSE}
## SUPPLY SIDE ### FLOORSPACE Wj
#attractiveness of a store is given by its size for this model

floorspace <- read.csv("https://raw.githubusercontent.com/christinabotros/Leeds-Food-Desert-Analysis/main/floorspace%20dataset.csv")

retail_leeds <- merge(retail_leeds, 
                      floorspace, 
                      by.x = "id", 
                      by.y = "id")

```

```{r Building the Spatial Interaction Model,   echo=TRUE, message = FALSE, warning= FALSE}

# Adding in variables to the distance matrix
travel_lines1 <- travel_lines
travel_lines1$floorspace <- retail_leeds$Floorspace[match(travel_lines1$dest, retail_leeds$id)]
travel_lines1$retailers <- retail_leeds$retailer.x[match(travel_lines1$dest, retail_leeds$id)]
travel_lines1$totalpop <- oa_map$TotalPop[match(travel_lines1$orig, oa_map$code)]  
travel_lines1$expenditure <- oa_map$expenditure[match(travel_lines1$orig, oa_map$code)]

## Getting Ai 
# note we can adjust brand attractive so that market share within Leeds matches that within the 
#Kantar WorldPanel grocery market shares
alpha = 1  

#beta can be calibrated to reflect people's ability to travel different distances 
beta = -0.5

#calculate some new wj^alpha and dij^beta values
wj2_alpha <- travel_lines1$floorspace^alpha
dist_beta <- travel_lines1$dist^beta
#calculate the first stage of the Ai values
travel_lines1$Ai1 <- wj2_alpha*dist_beta
#now do the sum over all js bit
A_i <- travel_lines1 %>% group_by(orig) %>% summarise(A_i = sum(Ai1))
#now divide in to 1
A_i <- A_i %>% st_drop_geometry()
A_i[,2] <- 1/A_i[,2]
#and write the A_i values back into the data frame
travel_lines1$A_i <- A_i$A_i[match(travel_lines1$orig,A_i$orig)]

```

```{r Production-constrained SIM (uncalibrated),   echo=TRUE, message = FALSE, warning= FALSE}

travel_lines1$O_i = travel_lines1$expenditure
travel_lines1$Wj = travel_lines1$floorspace
travel_lines1$Cij = travel_lines1$dist

travel_lines1$prodsimest <- travel_lines1$A_i*travel_lines1$O_i*wj2_alpha*dist_beta

prodsim <- dplyr::select(travel_lines1, c(orig, dest, prodsimest)) %>% st_drop_geometry()
prodsimExpenditure <- prodsim %>% pivot_wider(names_from = dest, values_from =prodsimest) 

#write.csv(prodsimExpenditure, "SIM_leeds.csv")

```

```{r Provision score for uncalibrated SIM,  echo=TRUE, message = FALSE, warning= FALSE}

# UNCALIBRATED SIM RESULTS 
Sij1 <- prodsim
Sij1$floorspace <- retail_leeds$Floorspace[match(Sij1$dest, retail_leeds$id)]
Sij1$pop <- oa_map$TotalPop[match(Sij1$orig, oa_map$code)]

Sum_at_j1 <-  prodsim %>% group_by(dest) %>% summarise(Sum_at_j1 = sum(prodsimest))
Sij1$sum <- Sum_at_j1$Sum_at_j1[match(Sij1$dest, Sum_at_j1$dest)]

Sij1$Total_Provision <- (Sij1$prodsimest/Sij1$sum)*Sij1$floorspace

Provision_Test1 <- dplyr::select(Sij1, c(orig, dest, Total_Provision)) 
Provision_Test11 <- Provision_Test1 %>% pivot_wider(names_from = dest, values_from =Total_Provision) 

# Individual provision 

Individual_Provision1 <-  Provision_Test1 %>% group_by(orig) %>% summarise(indiv = sum(Total_Provision))
Individual_Provision1$pop <- oa_map$TotalPop[match(Individual_Provision1$orig, oa_map$code)]
Individual_Provision1$individuals <- Individual_Provision1$indiv/Individual_Provision1$pop

provision_maptest1 <- oa_map %>%
  merge(., 
        Individual_Provision1, 
        by.x = "code", 
        by.y = "orig")

# qtm(provision_maptest1, 
#     fill = "indiv")
# 
# qtm(provision_maptest1, 
#     fill = "individuals")

chosen_bins = c(0, 1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000)

uncalib_provision <- tm_shape(Leeds) + tm_borders(col="black", alpha=NA) +
  tm_shape(provision_maptest1) + tm_fill("individuals", palette= "YlGn") + tm_borders(col="light grey", alpha=0.2)
uncalib_provision

tmap_save(uncalib_provision, "uncalibrated provision (individuals.png")

uncalib_provision1 <- tm_shape(Leeds) + tm_borders(col="black", alpha=NA) +
  tm_shape(provision_maptest1) + tm_fill("indiv", palette= "YlGn", breaks = chosen_bins) + tm_borders(col="light grey", alpha=0.2)
uncalib_provision1

tmap_save(uncalib_provision1, "uncalibrated provision (individuals.png")


```

```{r Calibrating the production-constrained SIM,    echo=TRUE, message = FALSE, warning= FALSE}
# hard coding the alpha values from excel 
alpha_R <- read.csv("https://raw.githubusercontent.com/christinabotros/Leeds-Food-Desert-Analysis/main/Leeds%20retailer%20alpha.csv")
head(alpha_R)

travel_lines1$alpha <- alpha_R$Alpha.Value[match(travel_lines1$retailers, alpha_R$Retailer)]

# hard coding beta values from excel calibration 

beta_dis <- read.csv("https://raw.githubusercontent.com/christinabotros/Leeds-Food-Desert-Analysis/main/Leeds%20OAC%20beta.csv")
head(beta_dis)

# join OAC to the travel_lines data and then use that to match the beta values 
travel_lines1$oac <-  oa_map$oac_supe_1[match(travel_lines1$orig, oa_map$code)]
travel_lines1$beta <- beta_dis$Beta[match(travel_lines1$oac, beta_dis$OAC)]

# recalculate model inputs for calibration 

#calculate some new wj^alpha and dij^beta values
calib_wj2_alpha <- travel_lines1$floorspace^travel_lines1$alpha
calib_dist_beta <- travel_lines1$dist^travel_lines1$beta
#calculate the first stage of the Ai values
travel_lines1$calib_Ai1 <- calib_wj2_alpha*calib_dist_beta
#now do the sum over all js bit
calib_A_i <- travel_lines1 %>% group_by(orig) %>% summarise(calib_A_i = sum(calib_Ai1))
#now divide in to 1
calib_A_i <- calib_A_i %>% st_drop_geometry()
calib_A_i[,2] <- 1/calib_A_i[,2]
#and write the A_i values back into the data frame
travel_lines1$calib_A_i <- calib_A_i$calib_A_i[match(travel_lines1$orig,calib_A_i$orig)]

```

```{r run the calibrated SIM,    echo=TRUE, message = FALSE, warning= FALSE}
travel_lines1$calibprodsimest <- travel_lines1$calib_A_i*travel_lines1$O_i*calib_wj2_alpha*calib_dist_beta

calibprodsim <- dplyr::select(travel_lines1, c(orig, dest, calibprodsimest)) %>% st_drop_geometry()
calibprodsimExpenditure <- calibprodsim %>% pivot_wider(names_from = dest, values_from =calibprodsimest) 

#write.csv(calibprodsimExpenditure, "calibSIM_leeds.csv")
```

```{r Provision score for calibrated SIM,  echo=TRUE, message = FALSE, warning= FALSE}
# (Sij / S*j)* sum of Sij for all of i 

Sij <- calibprodsim
Sij$floorspace <- retail_leeds$Floorspace[match(Sij$dest, retail_leeds$id)]
Sij$pop <- oa_map$TotalPop[match(Sij$orig, oa_map$code)]

Sum_at_j <-  calibprodsim %>% group_by(dest) %>% summarise(Sum_at_j = sum(calibprodsimest))
Sij$sum <- Sum_at_j$Sum_at_j[match(Sij$dest, Sum_at_j$dest)]

Sij$Total_Provision <- (Sij$calibprodsimest/Sij$sum)*Sij$floorspace

Provision_Test <- dplyr::select(Sij, c(orig, dest, Total_Provision)) 
Provision_Test <- Provision_Test %>% group_by(orig) %>% summarise(total_provision = sum(Total_Provision))

# Individual provision 

Provision_Test$pop <- oa_map$TotalPop[match(Provision_Test$orig, oa_map$code)]
Provision_Test$individuals <- Provision_Test$total_provision/Provision_Test$pop

Provision_Test <- Provision_Test %>% rename ("Calibrated SIM aggregate accessibility" = total_provision)
Provision_Test <- Provision_Test %>% rename ("Calibrated SIM accessibility per individual" = individuals)

provision_maptest <- oa_map %>%
  merge(., 
        Provision_Test, 
        by.x = "code", 
        by.y = "orig")

qtm(provision_maptest, 
    fill = "individuals")

qtm(provision_maptest, 
    fill = "total_provision")

provision_maptest0 <- tm_shape(Leeds) + tm_borders(col="black", alpha=NA) +
  tm_shape(provision_maptest) + tm_fill("individuals", palette= "YlGn") + tm_borders(col="light grey", alpha=0.2)
provision_maptest0

provision_maptest1 <- tm_shape(Leeds) + tm_borders(col="black", alpha=NA) +
  tm_shape(provision_maptest) + tm_fill("total_provision", palette= "YlGn", breaks = c(0, 1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000)) + tm_borders(col="light grey", alpha=0.2)
provision_maptest1

tmap_save(provision_maptest0, "calibrated individual provision.png")
tmap_save(provision_maptest1, "calibrated total provision.png")
```

```{r Incorporating indicative site in Aire Valley,  echo=TRUE, message = FALSE, warning= FALSE}
#  see policy document here  https://www.leeds.gov.uk/Local%20Plans/AVL%20AAP%20Adoption/04.%20Plans%20Illustrating%20the%20Policies%20Map%20Inset%20.pdf
# Located at: 435025.9, 431003.1 in ESPG:27700 using Google Maps 

AireValley <- data.frame(1, "AireValley", 35000, 435025.9, 431003.1)
names(AireValley) <- c("id", "retailer.x", "floorspace", "bng_e", "bng_n")
AireValley <-  st_as_sf(AireValley, coords = c("bng_e", "bng_n"), 
                        crs = 27700)

newlocation <- retailers_map + tm_shape(AireValley) + tm_symbols(col="green", scale = 0.6)
newlocation

tmap_save(newlocation, "Aire Valley Site.png")

```

```{r Distance Matrix between Origins and Destinations with NEW SITE,  echo=TRUE, message = FALSE, warning= FALSE}
# adding in the new store location to recalculate distances 
retail_leedsAV <- dplyr::select (retail_leeds, c(id, retailer.x, geometry))
AireValley1 <- dplyr::select (AireValley, c(id, retailer.x, geometry))

retail_leedsAV <- rbind(retail_leedsAV, AireValley1)

### Calculate distance matrix [Cij]

retail_leeds_ptsnew <- st_centroid(retail_leedsAV)
retail_leeds_ptsnew <- retail_leeds_ptsnew[,1]
qtm(retail_leeds_ptsnew)

#create a vector of all origin and destination points
all_od_ptsnew <- rbind(oa_leeds_pts, retail_leeds_ptsnew)
plot(all_od_ptsnew)
summary(all_od_ptsnew)

#create some vectors of the IDs
destination_shopsnew <- retail_leedsAV$id #vector of codes for your shops (that you can link back to your shop point data)

#this should create a square(ish) matrix from the list of origin and destination codes
tb_new <- as_tibble(matrix(nrow = length(OA_Origin_codes), ncol = length(destination_shopsnew), dimnames = (list(OA_Origin_codes,destination_shopsnew))))

tb_new <- tb_new %>% 
  mutate(row_name = OA_Origin_codes) %>% 
  column_to_rownames(var = "row_name")

tb_1_new <- tb_new %>% rownames_to_column(var = "orig")

tb_long_new <- pivot_longer(tb_1_new, cols = 2:ncol(tb_1_new), names_to = "dest")
tb_long_new$value <- 1

#now generate some staight-line flow lines. We could try and route these along roads
#but given how many, this would totally break your computer. Start easy. 
travel_lines_new <- od2line(flow = tb_long_new, zones = all_od_ptsnew, origin_code = "orig", dest_code = "dest")
travel_lines_new

distance_matrix <- geo_length(travel_lines_new)
#now attach this back to travel_lines
travel_lines_new$dist <- distance_matrix

floorspace <- read_xlsx(here::here("Data", "floorspace dataset.xlsx"))

retail_leedsAV <- rbind(retail_leedsAV, AireValley1)
retail_leedsAV$floorspace <- floorspace$Floorspace[match(retail_leedsAV$id,floorspace$id)]

#add in the floorspace for the new site at Aire Valley
retail_leedsAV$floorspace[is.na(retail_leedsAV$floorspace)] <- 35000 

# Adding in variables to the distance matrix
travel_lines_new1 <- travel_lines_new
travel_lines_new1$floorspace <- retail_leedsAV$floorspace[match(travel_lines_new1$dest, retail_leedsAV$id)]
travel_lines_new1$retailers <- retail_leedsAV$retailer.x[match(travel_lines_new1$dest, retail_leedsAV$id)]
travel_lines_new1$totalpop <- oa_map$TotalPop[match(travel_lines_new1$orig, oa_map$code)]  
travel_lines_new1$expenditure <- oa_map$expenditure[match(travel_lines_new1$orig, oa_map$code)]

travel_lines_new1$O_i = travel_lines_new1$expenditure
travel_lines_new1$Wj = travel_lines_new1$floorspace
travel_lines_new1$Cij = travel_lines_new1$dist

```

```{r Calibrating SIM with new site,  echo=TRUE, message = FALSE, warning= FALSE}
### CALIBRATING INDICATIVE SITE #####

# join OAC to the travel_lines data and then use that to match the beta values 
travel_lines_new1$oac <-  oa_map$oac_supe_1[match(travel_lines_new1$orig, oa_map$code)]
travel_lines_new1$beta <- as.numeric(beta_dis$Beta[match(travel_lines_new1$oac, beta_dis$OAC)])

travel_lines_new1$alpha <- alpha_R$Alpha.Value[match(travel_lines_new1$retailers, alpha_R$Retailer)]
travel_lines_new1$alpha[is.na(travel_lines_new1$alpha)] <- 1 

# recalculate model inputs for calibration 

#calculate some new wj^alpha and dij^beta values
calib_wj2_alpha1 <- travel_lines_new1$floorspace^travel_lines_new1$alpha
calib_dist_beta1 <- travel_lines_new1$dist^travel_lines_new1$beta
#calculate the first stage of the Ai values
travel_lines_new1$calib_Ai1 <- calib_wj2_alpha1*calib_dist_beta1
#now do the sum over all js bit

new_calib_A_i <- travel_lines_new1 %>% group_by(orig) %>% summarise(new_calib_A_i = sum(calib_Ai1))
#now divide in to 1
new_calib_A_i <- new_calib_A_i %>% st_drop_geometry()
new_calib_A_i[,2] <- 1/new_calib_A_i[,2]
#and write the A_i values back into the data frame
travel_lines_new1$calib_A_i <- new_calib_A_i$new_calib_A_i[match(travel_lines_new1$orig,new_calib_A_i$orig)]

```

```{r Run calibrated SIM with NEW SITE,  echo=TRUE, message = FALSE, warning= FALSE}
#run the calibrated model with new site

travel_lines_new1$new_calibprodsimest <- travel_lines_new1$calib_A_i*travel_lines_new1$O_i*calib_wj2_alpha1*calib_dist_beta1

new_calibprodsim <- dplyr::select(travel_lines_new1, c(orig, dest, new_calibprodsimest)) %>% st_drop_geometry()
new_calibprodsimExpenditure <- new_calibprodsim %>% pivot_wider(names_from = dest, values_from =new_calibprodsimest) 

#write.csv(new_calibprodsimExpenditure, "NEWcalibSIM_leeds.csv")
```

```{r Calculate new provision with NEW SITE,  echo=TRUE, message = FALSE, warning= FALSE}
########### ACCESSIBILITY / PROVISION WITH NEW AIRE VALLEY STORE #############

# (Sij / S*j)* sum of Sij for all of i 

Sij_new <- new_calibprodsim
Sij_new$floorspace <- retail_leeds$Floorspace[match(Sij_new$dest, retail_leeds$id)]
Sij_new$floorspace[is.na(Sij_new$floorspace)] <- 35000 
Sij_new$pop <- oa_map$TotalPop[match(Sij_new$orig, oa_map$code)]

Sum_at_j_new <-  new_calibprodsim %>% group_by(dest) %>% summarise(Sum_at_j = sum(new_calibprodsimest))
Sij_new$sum <- Sum_at_j_new$Sum_at_j[match(Sij_new$dest, Sum_at_j_new$dest)]

Sij_new$Total_Provision <- (Sij_new$new_calibprodsimest/Sij_new$sum)*Sij_new$floorspace

new_Provision_Test <- dplyr::select(Sij_new, c(orig, dest, Total_Provision)) 
new_Provision_Test <- new_Provision_Test %>% group_by(orig) %>% summarise(total_provision = sum(Total_Provision))

# Individual provision 

new_Provision_Test$pop <- oa_map$TotalPop[match(new_Provision_Test$orig, oa_map$code)]
new_Provision_Test$individuals <- new_Provision_Test$total_provision/new_Provision_Test$pop
head(new_Provision_Test)

new_Provision_Test$change_total <- new_Provision_Test$total_provision - Provision_Test$total_provision 
new_Provision_Test$change_indiv <- new_Provision_Test$individuals - Provision_Test$individuals 

#MAPPING THE NEW PROVISIONS AND CHANGES 

new_provision_map <- oa_map %>%
  merge(., 
        new_Provision_Test, 
        by.x = "code", 
        by.y = "orig")

#make a very quick map provision by OA
tmap_mode("plot")

qtm(new_provision_map, 
    fill = "total_provision")

qtm(new_provision_map, 
    fill = "individuals")

qtm(new_provision_map, 
    fill = "change_total")

qtm(new_provision_map, 
    fill = "change_indiv")

tmap_mode("plot")

provisionmap2 <- tm_shape(Leeds) + tm_borders(col="black", alpha=NA) +
  tm_shape(new_provision_map) + tm_fill("individuals", palette= "YlGn") + tm_borders(col="light grey", alpha=0.2)
provisionmap2

provisionmap3 <- tm_shape(Leeds) + tm_borders(col="black", alpha=NA) +
  tm_shape(new_provision_map) + tm_fill("total_provision", palette= "YlGn", breaks = c(0, 1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000)) + tm_borders(col="light grey", alpha=0.2)
provisionmap3

provisionmap4 <- tm_shape(Leeds1) + tm_borders(col="black", alpha=NA) +
  tm_shape(new_provision_map) + tm_fill("change_indiv", palette= "YlGn") + tm_borders(col="light grey", alpha=0.2) + tm_shape(AireValley) + tm_symbols(col="red", scale =0.4)
provisionmap4

provisionmap5 <- tm_shape(Leeds1) + tm_borders(col="black", alpha=NA) +
  tm_shape(new_provision_map) + tm_fill("change_total", palette= "YlGn") + tm_borders(col="light grey", alpha=0.2) + tm_shape(AireValley) + tm_symbols(col="red", scale =0.4)
provisionmap5


map_with_new_store <- provisionmap2 + tm_shape(AireValley) + tm_symbols(col="red", scale =0.3)
map_with_new_store

tmap_save(provision_maptest2, "calibrated individual provision (new site).png")
tmap_save(provision_maptest3, "calibrated total provision (new site).png")
tmap_save(provision_maptest3, "calibrated indiv provision (new site) change.png")
tmap_save(map_with_new_store, "calibrated total provision w (new site).png")

tmap_save(provisionmap4, "change in provision (indiv).png")
tmap_save(provisionmap5, "change in provision (total).png")
```

```{r Mapping distances covered by NEW SITE,  echo=TRUE, message = FALSE, warning= FALSE}
### understanding travel lines to the new store 

new_store <- filter(travel_lines_new, dest == 1)
new_store_500 <- filter(new_store, dist <1000)
new_store_3000 <- filter(new_store, dist <3000)

tm_shape(Leeds) + tm_borders(col="black") + tm_shape(oa_map$geometry) + tm_borders(col="light grey", alpha=0.2) +
  tm_shape(new_store_500) +
  tm_lines(palette = "plasma",
           lwd = "dist",
           alpha = 0.5,
           col = "dist")

# zoom in to just the area where the distances exist
threeKM <- tm_shape(Leeds1) + tm_borders(col="black") + tm_shape(oa_map$geometry) + tm_borders(col="light grey", alpha=0.2) +
  tm_shape(new_store_3000) +
  tm_lines(palette = "plasma",
           lwd = "dist",
           alpha = 0.5,
           col = "dist")

newlocation <- newlocation <-    tm_shape(retail_leeds) + 
                  tm_symbols(col ="red", scale =.3) + 
              tm_shape(AireValley) + tm_symbols(col="green", scale = 0.6)
newlocation

new_store_dis<- threeKM +newlocation
new_store_dis

tmap_save(new_store_dis, "3km distance from new store.png")

```

```{r Attraction-Constrained (destination) SIMs,  echo=TRUE, message = FALSE, warning= FALSE}
### Attraction-Constrained (destination) Spatial Interaction Model 

#Oi = floorspace
#Wj = expenditure/people 
#Cij = distance // dist_beta is the same 

travel_lines2 <- travel_lines
travel_lines2$floorspace <- retail_leeds$Floorspace[match(travel_lines2$dest, retail_leeds$id)]
travel_lines2$retailers <- retail_leeds$retailer.x[match(travel_lines2$dest, retail_leeds$id)]
travel_lines2$totalpop <- oa_map$TotalPop[match(travel_lines2$orig, oa_map$code)]  
travel_lines2$expenditure <- oa_map$expenditure[match(travel_lines2$orig, oa_map$code)]
```


```{r Using expenditures as attractiveness of OAs,  echo=TRUE, message = FALSE, warning= FALSE}
## Attraction-constrained V1 - expenditures 

#calculate some new wj^alpha and dij^beta values
wj2_alpha2 <- travel_lines2$expenditure^alpha

travel_lines2$Wj = travel_lines2$expenditure
travel_lines2$O_i = travel_lines2$floorspace
travel_lines2$Cij = travel_lines2$dist

travel_lines2$attractsimest <- travel_lines1$A_i*travel_lines2$O_i*wj2_alpha2*dist_beta

attractionsim <- dplyr::select(travel_lines2, c(orig, dest, attractsimest)) %>% st_drop_geometry()
attractsimExpenditure <- attractionsim %>% pivot_wider(names_from = dest, values_from =attractsimest)
```


```{r Using population as attractiveness of OAs,  echo=TRUE, message = FALSE, warning= FALSE}
## Attraction-constrained V2 - people 

wj2_alpha3 <- travel_lines2$totalpop^alpha

travel_lines2$Wj = travel_lines2$totalpop
travel_lines2$O_i = travel_lines2$floorspace
travel_lines2$Cij = travel_lines2$dist

travel_lines2$attractsimest2 <- travel_lines1$A_i*travel_lines2$O_i*wj2_alpha3*dist_beta

attractionsim2 <- dplyr::select(travel_lines2, c(orig, dest, attractsimest2)) %>% st_drop_geometry()
attractsimPeople <- attractionsim2 %>% pivot_wider(names_from = dest, values_from =attractsimest2)
```


```{r Destination constrained model outputs,  echo=TRUE, message = FALSE, warning= FALSE}
##### GETTING MODEL OUTPUTS ######
# 1. floorspace per OA by population attractions 
attractsimPeople$floorspacebyPeople <- rowSums( attractsimPeople[,2:206] )

floorspace_people <- dplyr::select(attractsimPeople, c(orig, floorspacebyPeople))

# 2. floorspace per OA by expenditure attractions 
attractsimExpenditure$floorspacebyExpen <- rowSums( attractsimExpenditure[,2:206] )
floorspace_expenditure <- dplyr::select(attractsimExpenditure, c(orig, floorspacebyExpen))

destination_constrained_E <- oa_map %>%
  merge(., 
        floorspace_expenditure, 
        by.x = "code", 
        by.y = "orig")


destination_constrained_P <- oa_map %>%merge(., 
                                 floorspace_people, 
                                 by.x = "code", 
                                 by.y = "orig")

head(destination_constrained)

tmap_mode("plot")

qtm(destination_constrained_P, 
    fill = "floorspacebyPeople")

qtm(destination_constrained_E, 
    fill = "floorspacebyExpen")

destination_constrained_P <- destination_constrained_P %>% rename('Floorspace provision by attractiveness (people)' = floorspacebyPeople)

destination_constrained_E <- destination_constrained_E %>% rename('Floorspace provision by attractiveness (expenditure)' = floorspacebyExpen)

floorspace_people <- tm_shape(Leeds1) + tm_borders(col="black", alpha=NA) +
  tm_shape(destination_constrained_P) + tm_fill("Floorspace provision by attractiveness (people)", palette= "YlGn", style = "pretty") + tm_borders(col="light grey", alpha=0.2) + 
  tm_layout(legend.outside = TRUE)
floorspace_people

floospace_expenditure <- tm_shape(Leeds1) + tm_borders(col="black", alpha=NA) +
  tm_shape(destination_constrained_E) + tm_fill("Floorspace provision by attractiveness (expenditure)", palette= "YlGn", style = "pretty") + tm_borders(col="light grey", alpha=0.2) 
floospace_expenditure 

tmap_save(floorspace_people, "floorspace_people.png")
tmap_save(floorspace_expenditure, "floorspace_expenditure.png")

t = tmap_arrange(floorspace_people, floospace_expenditure, ncol = 2)
t

tmap_save(t, "floorspaceprovision.png")

```

```{r Calculating Hansen Accessibility,  echo=TRUE, message = FALSE, warning= FALSE}
# Hansen Accesibility 
# this is the same as Ai in our SIM:

wj2_alpha <- travel_lines1$floorspace^alpha
dist_beta <- travel_lines1$dist^beta
travel_lines1$Ai1 <- wj2_alpha*dist_beta
hansen <- travel_lines1 %>% group_by(orig) %>% summarise(A_i = sum(Ai1))
hansen <- hansen %>% st_drop_geometry()
hansen <- hansen %>% rename('Hansen Accessibility Score' = A_i)

hansen_map <- oa_map %>%
  merge(., 
        hansen, 
        by.x = "code", 
        by.y = "orig")

# qtm(hansen_map, 
#     fill = "Hansen Accessibility Score")

hansenmapp <- tm_shape(Leeds) + tm_borders(col="black", alpha=NA) +
              tm_shape(hansen_map) + tm_fill("Hansen Accessibility Score") + 
                  tm_borders(col="light grey", alpha=0.2) + 
                  tm_layout(title = "Hansen Accessibility Score in Leeds Output Areas", title.size = 1.1, title.position = c("centre", "top"))
hansenmapp 

tmap_save(hansenmapp, "hansen accessibility.png")

```