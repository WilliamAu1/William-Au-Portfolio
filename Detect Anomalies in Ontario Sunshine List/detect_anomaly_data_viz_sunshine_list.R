rm(list = ls())  # clear environment
library(rmarkdown)  # markdown
library(knitr)  # knitr
library(tidyverse)  # for tidy data import and wrangling
library(factoextra)  # for cluster visualization
library(fpc)  # for dbscan clustering
library(caret)  # for dummy variables
library(cluster)  # for clustering
library(GGally)  # for matrix plotting
library(RColorBrewer)  # for color palettes
library(scales)
library(ClusterR)
memory.limit(size = 16141 * 4)
gc()  # garbage collection
# d
# import 2019 data
s01 <- as_tibble(read_csv(
    "Detect Anomalies in Ontario Sunshine List/tbs-pssd-compendium-2019-en-2020-12-21.csv", 
    col_names = TRUE)) %>%
    mutate(
        salary = readr::parse_number(`Salary Paid`),
        taxable_ben = readr::parse_number(`Taxable Benefits`)) %>%
    select(-c(`Salary Paid`, `Taxable Benefits`))

# EDA - sector (18), employer >1000
ggplot(
    data = s01,
    aes(
        x = Sector,
        y = salary)) +
    geom_violin(trim = FALSE, fill = "green") + 
    coord_flip() +
    scale_y_continuous(name = "Salary", labels = comma) +
    theme_minimal()
ggplot(
    data = s01,
    aes(
        x = Sector,
        y = taxable_ben)) +
    geom_violin(trim = FALSE, fill = "green") + 
    coord_flip() +
    scale_y_continuous(name = "Taxable benefits", labels = comma) +
    theme_minimal()
tmp <- s01 %>%
    sample_n(size = 500, replace = FALSE)
ggpairs(
    data = tmp,
    columns = 7:8,
    aes(
        alpha = 0.1),
    upper = list("cor")) + 
    theme_minimal()

# kmeans for data reduction
set.seed(888)
tmp_km <- kmeans(s01[, 7:8], centers = 1000, nstart = 10, trace = FALSE)
tmp_ctr <- as_tibble(tmp_km$centers)
tmp_clus <- as_tibble(tmp_km$cluster)
s02_dist <- daisy(tmp_ctr, metric = "euclidean")

# ----- tune hyperparameters for dbscan clustering -----
tmp <- dbscan::kNNdist(s02_dist, k = 1, all = TRUE)
dbscan::kNNdistplot(tmp, k = 1)
abline(h = 1000, lty = 2, col = "red")  # eps = 1000
tmp <- dbscan::kNNdist(s02_dist, k = 10, all = TRUE)
dbscan::kNNdistplot(tmp, k = 10)
abline(h = 20000, lty = 2, col = "red")  # eps = 20000
tmp <- dbscan::kNNdist(s02_dist, k = 400, all = TRUE)
dbscan::kNNdistplot(tmp, k = 400)
abline(h = 1000000, lty = 2, col = "red")  # eps = 1000000
tmp <- dbscan::kNNdist(s02_dist, k = 950, all = TRUE)
dbscan::kNNdistplot(tmp, k = 950)
abline(h = 2500000, lty = 2, col = "red")  # eps = 2500000

# modeling
set.seed(888)
s03_clus <- fpc::dbscan(
    data = s02_dist, 
    eps = 2500000,
    MinPts = 400,
    scale = FALSE,
    method = "hybrid",
    seeds = FALSE,
    showplot = FALSE,
    countmode = NULL)

# use dbscan to score kmeans, then assign back to obs
centers <- as.matrix(tmp_km$centers)
tmp2 <- s01 %>%
    bind_cols(as_tibble(as.vector(ClusterR::predict_KMeans(data = s01[, 7:8], 
    CENTROIDS = centers, threads = 1)))) %>%
    mutate(km_cluster = as.character(value)) %>%
    select(-value) 
tmp3 <- as_tibble(s03_clus$cluster) %>%
    mutate(db_cluster = as.character(value),
        km_cluster = as.character(row_number())) %>%
    select(-value)
s04_clus <- tmp2 %>%
    left_join(tmp3, by = "km_cluster")
s04_clus %>% group_by(db_cluster) %>% count() %>% arrange(n)  # 0.95%
1510/(1510+156659)

ggplot(
    data = s04_clus,
    aes(
        x = db_cluster,
        y = salary)) +
    geom_violin(trim = FALSE, fill = "green") + 
    coord_flip() +
    scale_y_continuous(name = "Salary", labels = comma) +
    stat_summary(fun.data = mean_sdl, geom = "pointrange", color = "red") +
    theme_minimal()
ggplot(
    data = s04_clus,
    aes(
        x = db_cluster,
        y = taxable_ben)) +
    geom_violin(trim = FALSE, fill = "green") + 
    coord_flip() +
    scale_y_continuous(name = "Taxable benefits", labels = comma) +
    stat_summary(fun.data = mean_sdl, geom = "pointrange", color = "red") +
    theme_minimal()


tmp_plt <- s04_clus %>%
    sample_n(size = 100000, replace = FALSE)
ggplot(tmp_plt,
    aes(x = taxable_ben, y = salary, group = db_cluster)) +
    geom_point(aes(color = db_cluster)) + theme_minimal()
tmp_pca <- prcomp(s01[, 7:8], scale = TRUE)
fviz_pca_biplot(tmp_pca, label = "var", habillage = s04_clus$db_cluster,
               addEllipses = FALSE, ellipse.level = 0.95)
fviz_cluster(s03_clus, data = s02_dist, stand = TRUE, ellipse = TRUE, 
    show.clust.cent = TRUE, palette = "paired", geom = "point", pointsize = 1,
    repel = TRUE, ggtheme = theme_minimal()) + coord_fixed() 