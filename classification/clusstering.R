debugSource("classification/classificationUtils.R")
library(gtools)
library(cluster)
library(stats)
library("Kendall")
library("forecast")
library("plyr")

getDataForCluster <- function(data, clusters, clusterNumber){
  cl = clusters[ clusters == clusterNumber]
  cl = names(cl)
  cl = data[rownames(data) %in% cl,]
  return(cl)
}

createCountTableInClusters <- function(c1, c2, c3, c4, c5, clubs){
  c1H = sapply(clubs, function(x) table(c1$home_team_fk)[x])
  c1A = sapply(clubs, function(x) table(c1$away_team_fk)[x])
  c1S = c1H+c1A
  
  c2H = sapply(clubs, function(x) table(c2$home_team_fk)[x])
  c2A = sapply(clubs, function(x) table(c2$away_team_fk)[x])
  c2S = c2H+c2A
  
  c3H = sapply(clubs, function(x) table(c3$home_team_fk)[x])
  c3A = sapply(clubs, function(x) table(c3$away_team_fk)[x])
  c3S = c3H+c3A
  
  c4H = sapply(clubs, function(x) table(c4$home_team_fk)[x])
  c4A = sapply(clubs, function(x) table(c4$away_team_fk)[x])
  c4S = c4H+c4A
  
  c5H = sapply(clubs, function(x) table(c5$home_team_fk)[x])
  c5A = sapply(clubs, function(x) table(c5$away_team_fk)[x])
  c5S = c5H+c5A
  
  #df = data.frame(c1H,c1A,c2H,c2A,c3H,c3A,c4H,c4A,c5H,c5A,c1S,c2S,c3S,c4S,c5S)
  df = data.frame(c1S,c2S,c3S,c4S,c5S)
  return(df)
}

splitDataToPeriods <- function(data, yearsInPeriod){
  seasons = unique(data$season)
  resultData = list()
  for(i in 1:(length(seasons) -yearsInPeriod + 1)){
    end = i + yearsInPeriod -1
    tmpData = data[ data$season %in% seasons[i:end],]
    name = paste(seasons[i], seasons[end], sep = "-")
    resultData[[name]] = tmpData
  }
  
  return(resultData)
}

createTable <-function(c1, c2, c3, c4, c5, clubs, n){
  return(createCountTableInClusters(c1[[n]], c2[[n]], c3[[n]], c4[[n]], c5[[n]], clubs ))
}

createSortTable <- function(t){
  tmpT =  t[order(t$c1S, decreasing = T),1:5]
  df = data.frame(rownames(tmpT), tmpT$c1S)
  tmpT =  t[order(t$c2S, decreasing = T),1:5]
  df = data.frame(df, rownames(tmpT), tmpT$c2S)
  
  tmpT =  t[order(t$c3S, decreasing = T),1:5]
  df = data.frame(df, rownames(tmpT), tmpT$c3S)
  
  tmpT =  t[order(t$c4S, decreasing = T),1:5]
  df = data.frame(df, rownames(tmpT), tmpT$c4S)

  tmpT =  t[order(t$c5S, decreasing = T),1:5]
  df = data.frame(df, rownames(tmpT), tmpT$c5S)
}

clustering <-function(data, nClusters){

  dataForClustering = getFilteredData(data)
  
  dataForClustering = dataForClustering[complete.cases(dataForClustering),]
  
  splitedData = splitDataToPeriods(data, 3)
  splitedData[["all"]] = data
  
  splitedDataForClustering = splitDataToPeriods(dataForClustering, 3)
  splitedDataForClustering[["all"]]  = dataForClustering
  splitedDataForClustering = lapply(splitedDataForClustering, function(x) {x$season_fk =NULL; x})
  
#   splitedDataForClustering = lapply(splitedDataForClustering, normalize, byrow = FALSE)
  distances = sapply(splitedDataForClustering, dist)
  hc = lapply(distances, hclust)
  clusters = sapply(hc, function(x) cutree(x, k =nClusters))
  
  for(i in 1:length(splitedData)){
    tmpData = splitedData[[i]]
    tmpClust = clusters[[i]]
    df = data.frame(tmpClust)
    tmpData$cluster = df$tmpClust[match(rownames(tmpData), rownames(df))]
    splitedData[[i]] = tmpData
  }
  return(splitedData)
}

clustering2 <-function(data, nClusters, typeOf){
  splitedData = splitDataToPeriods(data, 3)
  #splitedData[["all"]] = data
  
  splitedData = lapply(splitedData, clusteringOnePart, nClusters = nClusters, typeOf = typeOf)
  
  return(splitedData)
}

clusteringOnePart <-function(data, nClusters, typeOf = "hc"){
  
  data = data[complete.cases(data),]
  
  dataForClustering = getFilteredData(data)
    
  dataForClustering = data.table(sapply(dataForClustering, normalize01))
  clusters = NULL  

  if(typeOf == "hc"){
    rownames(dataForClustering) = rownames(data)
    distances = dist(dataForClustering)
    set.seed(5)
    hc = hclust(distances)
    clusters = cutree(hc, k =nClusters)
    df = data.frame(clusters)
    data$cluster = df$clusters[match(rownames(data), rownames(df))]
  }else if( typeOf == "km"){
    set.seed(5)
    km = kmeans(dataForClustering, centers = nClusters)
    clusters = km$cluster
    df = data.frame(clusters)
    rownames(df) = rownames(data)
    data$cluster = df$clusters[match(rownames(data), rownames(df))]
  }
  
  
#   data$cluster = df$clusters[match(rownames(data), rownames(df))]
  
  
  return(data)
}

normalize01 <- function(x) {
  return ((x - min(x)) / (max(x) - min(x)))
}

getFilteredData <- function(data){  
  labelsToInlcude = c(#"av_goals",
                      #"av_goals_half_time",
                      "av_shots",
                      "av_shots_on_target",
                      "av_corners",
                      "av_fouls",
                      "av_yellows",
                      "av_reds",
                      "av_shots_outside_target",
                      #"av_op_goals",
                      #"av_op_goals_half_time",
                      "av_op_shots",
                      "av_op_shots_on_target",
                      "av_op_corners",
                      "av_op_fouls",
                      "av_op_yellows",
                      "av_op_reds",
                      "av_op_shots_outside_target")
  dataForClustering = data[, labelsToInlcude, with = FALSE ]
  return(dataForClustering)
}

#TODO change to most newCluster
getMostCommonClusterForClub <- function(data){
  tab = table(data$team, data$cluster)
  tabCl = table(data$cluster)
  tab = data.frame(tab)
  result = data.frame(unique(data$team))
  colnames(result) = "team"
  result$MCCluster = sapply(result$team, function(x){
    club = x
    tab2 = tab[tab$Var1 == club, ]
    var = tab2$Var2[tab2$Freq == max(tab2$Freq)]
    if(length(var) == 1){
      var = var[1]
    }
    else{
      min = 100000
      minCl = 0
      for(tVar in var){
        if(tabCl[tVar] < min){
          minCl = tVar
        }
      }
      var = minCl
    }
    return(var)
  }) 
  return(result)
}

#TODO what with ==
matchClusters <-function(clusteredData){
  allTransitions = list()
  for(i in 1:12){
    df1 = clusteredData[[i]]
    df2 = clusteredData[[i+1]]
    df1 = data.frame(rownames(df1), df1$cluster)
    df2 = data.frame(rownames(df2), df2$cluster)
    colnames(df1) = c("id", "cluster")
    colnames(df2) = c("id", "cluster")
    s1 = split(df1, df1$cluster)
    s2 = split(df2, df2$cluster)
    
    l1 = length(s1)
    l2 = length(s2)
    
    clusterTransitions = list()
    
    for(j in 1:l1){
      nextCluster = j
      jaccard = -1
      for(k in 1:l2){
        newJaccard = jaccardIndex(s1[[j]]$id, s2[[k]]$id)
        if(newJaccard > jaccard){
          jaccard = newJaccard
          nextCluster = k
        }else if(newJaccard == jaccard & newJaccard > 0){
          print("check")
        }
      }
      clusterTransitions[[j]] = c(j, nextCluster)
    }
    
    allTransitions[[i]]=clusterTransitions
  }
  result = list(transitions = allTransitions)
  
  nClusters = length(allTransitions[[1]])
  
  trRows = matrix(NA, nrow = nClusters, ncol = 13, byrow = FALSE)
  trRows[,1] = seq(1:nClusters)
  trRows = as.data.frame(trRows)
  
  for(i in 1:12){
    tmp = allTransitions[[i]]
    for(j in 1:nClusters){
      first = tmp[[j]][[1]]
      last = tmp[[j]][[2]]
      if(nrow(trRows[trRows[i] == first,]) == 0){
        trRows = rbind(trRows, rep(NA))
        trRows[nrow(trRows), i] = first
        trRows[nrow(trRows), i + 1] = last
      }
      else{
        trRows[trRows[i] == first & !is.na(trRows[i]),i + 1] = last
      }
    }
  }
  
  used = unique(trRows$V13)
  toUse = c(1, 2, 3, 4, 5)
  toUse = setdiff(toUse, used)
  
  for(t in toUse){
    trRows = rbind(trRows, NA)
    trRows[ nrow(trRows), 13 ] = t
  }
  
  result$trRows = trRows
  return(result)
}

printTopNTeams <- function(clusteredData, trRow, n){
  commonsClubs = list()
  for(i in 1: 13){
    tmp = clusteredData[[i]]
    cNumber = as.numeric(trRow[i])
    if(is.na(cNumber)){
      next
    }
    tmp = tmp[ tmp$cluster == cNumber, ]
    tab = table(tmp$team)
    tab = tab[order(tab, decreasing = TRUE)]
    tab = data.frame(tab[1:n])
    colnames(tab) = c("count")
    tab = data.frame(rownames(tab), tab$count)
    colnames(tab) = c("club", "count")
    rownames(tab) = NULL
    tab = tab[ tab$count > 0, ]
    for(j in 1:nrow(tab)){
      key = as.character(tab[j, 1])
      if(key %in% names(commonsClubs)){
        commonsClubs[key] = as.numeric(commonsClubs[key]) + 1
      }
      else{
        commonsClubs[key] = 1
      }
    }
    print(i)
    print(tab)
  }
  
  print("Often top clubs")
  commonsClubs = data.frame(unlist(commonsClubs))
  colnames(commonsClubs) = c("count")
  commonsClubs = data.frame(rownames(commonsClubs), commonsClubs$count)
  colnames(commonsClubs) = c("club", "count")
  commonsClubs = commonsClubs[ order(commonsClubs$count, decreasing = TRUE), ]
  print(commonsClubs)
}

jaccardForTransitions <- function(clusteredData, trRow){
  for(i in 1:12){
    tmp = clusteredData[[i]]
    tmp2 = clusteredData[[i+1]]
    if(is.na(trRow[i])){
      print(NA)
      next
    }
    cNumber = as.numeric(trRow[i])
    cNumber2 = as.numeric(trRow[i+1])
    tmp = tmp[ tmp$cluster == cNumber, ]
    tmp2 = tmp2[ tmp2$cluster == cNumber2, ]
    cat(cNumber, "->", cNumber2, ": ", jaccardIndex(tmp$id, tmp2$id), 
        "(", length(tmp$id), "/", lengthOfIntersect(tmp$id, tmp2$id),
        "/", length(tmp2$id), ")", "\n")
  }
}

normalizeClusterNames <-function(clusteredData, tr){
  transitions = tr$transitions
  trRows = tr$trRows
  clusterNumberToUse = 1
  
  
  fromPrev = numeric()
  prevPrev = numeric()
  
  for(i in 1:12){
    prevPrev = fromPrev
    fromPrev = numeric();
    
    tmpTr = transitions[[i]]
    curData = clusteredData[[i]]
    nextData = clusteredData[[i+1]]
    nextData$newCluster = NA
    if(!("newCluster" %in% colnames(curData))){
      curData$newCluster = NA
    }
    
    for(j in 1:length(tmpTr)){
      curTr = tmpTr[[j]]
      t1 = curTr[1]
      t2 = curTr[2]
      
      fromPrev = append(fromPrev, t2)
      
      newCluster = unique(nextData$newCluster[ nextData$cluster == t2 ]) 
      newClusterPrev = NA
      
      if(is.na(newCluster)){
        newCluster = unique(curData$newCluster[ curData$cluster == t1 ]) 
        newClusterPrev = unique(curData$newCluster[ curData$cluster == t1 ])
      }
      
      if(is.na(newCluster)){
        newCluster = paste("c", clusterNumberToUse, sep = "")
        clusterNumberToUse = clusterNumberToUse + 1
        newClusterPrev = newCluster
      }
      else if(!(t1 %in% prevPrev)){
        newClusterPrev =  paste("c", clusterNumberToUse, sep = "")
        clusterNumberToUse = clusterNumberToUse + 1
      }
      
      if(is.na(unique(curData$newCluster[ curData$cluster == t1 ]))){
        curData$newCluster[ curData$cluster == t1 ] = newClusterPrev
      }
      
      if(is.na(unique(nextData$newCluster[ nextData$cluster == t2 ]))){
        nextData$newCluster[ nextData$cluster == t2 ] = newCluster
      }
      
      
    }
    clusteredData[[i]] = curData
    clusteredData[[i+1]] = nextData
  }
  
  
  curData = clusteredData[[13]]
  clusters = unique(curData$cluster)
  for(i in clusters){
    newCluster = unique(curData$newCluster[ curData$cluster == i ]) 
    if(is.na(newCluster)){
      newCluster = paste("c", clusterNumberToUse, sep = "")
      clusterNumberToUse = clusterNumberToUse + 1
      curData$newCluster[ curData$cluster == i ] = newCluster
    }
  }
  
  clusteredData[[13]] = curData
    
  newTrRows = trRows
  
  for(i in 1:13){
    tmp = clusteredData[[i]]
    for(j in 1:nrow(newTrRows)){
      oldCluster = newTrRows[j, i]
      if(is.na(oldCluster)){
        next
      }
      
      newCluster = unique(tmp$newCluster[ tmp$cluster == oldCluster])
      newTrRows[j, i] = newCluster
    }
  }
  
  tr$newTrRows = newTrRows
  return(list( data = clusteredData, newTr = tr))
}

calculateImportance <- function(clusteredData, c = 0.0001){
  labels = c(#"av_goals",
             #"av_goals_half_time",
             "av_shots",
             "av_shots_on_target",
             "av_corners",
             "av_fouls",
             "av_yellows",
             "av_reds",
             "av_shots_outside_target",
             #"av_op_goals",
             #"av_op_goals_half_time",
             "av_op_shots",
             "av_op_shots_on_target",
             "av_op_corners",
             "av_op_fouls",
             "av_op_yellows",
             "av_op_reds",
             "av_op_shots_outside_target")
  importance = list()
  for(k in 1:13){
    data = clusteredData[[k]]
    tmpRes = numeric()
    for(l in 1:length(labels)){
      label = labels[l]
      # if(k ==8){
      #   print("p")
      # }
      df = data.frame(data$newCluster, data[,label, with = FALSE])
      colnames(df) = c("newCluster", label)
      means = aggregate(df[2], by=list(data$newCluster), mean)
      means = as.list(means[2])
      means = unlist(means)
      std.devs = aggregate(df[2], by=list(data$newCluster), sd)
      std.devs = as.list(std.devs[2])
      std.devs= unlist(std.devs)
      pairwise.score = matrix(nrow = length(means), ncol = length(means))
      for (i in 1:length(means)){
        for (j in 1:length(means)){
          if (i != j){
            pairwise.score[i,j] = abs(means[[i]] - means[[j]])^2 /
              ((std.devs[[i]] + c) * (std.devs[[j]] + c ))
          }
        }
      }
      attribute.importance = sum(pairwise.score, na.rm = TRUE)
      # if(k ==8){
      #   print("p")
      # }
      tmpRes[label] = attribute.importance
    }
    tmpRes = data.frame(feature = names(tmpRes), importance = tmpRes)
    tmpRes = tmpRes[ order(tmpRes$importance, decreasing = TRUE), ]
    rownames(tmpRes) = NULL
    importance[[k]] = tmpRes
  }
  return(importance)
}

mergeImportance <-function(importance){
  mergedData = data.frame(feature = numeric(0), imporatnce = numeric(0), 
                          position = numeric(0), period = numeric(0))
  for(i in 1:13){
    tmp = importance[[i]]
    tmp$position = 1:nrow(tmp)
    tmp$period = i
    mergedData = rbind(mergedData, tmp)
  }
  return(mergedData)
}

calculateMeansAndSDForFeatures <-function(clusteredData){
  labels = c("av_goals",
             "av_goals_half_time",
             "av_shots",
             "av_shots_on_target",
             "av_corners",
             "av_fouls",
             "av_yellows",
             "av_reds",
             "av_shots_outside_target",
             "av_op_goals",
             "av_op_goals_half_time",
             "av_op_shots",
             "av_op_shots_on_target",
             "av_op_corners",
             "av_op_fouls",
             "av_op_yellows",
             "av_op_reds",
             "av_op_shots_outside_target")
  nrows = length(labels)
  means = data.frame(matrix(0, ncol = nrows, nrow = 13))
  stdDevs = data.frame(matrix(0, ncol = nrows, nrow = 13))
  colnames(means) = labels
  colnames(stdDevs) = labels
  rownames(means) = 1:13
  rownames(stdDevs) = 1:13
  for(label in labels){
    for(i in 1:13){
      tmp = clusteredData[[i]]
      data = tmp[[label]]
      tmpMean = mean(data)
      tmpStdDev = sd(data)
      means[i, label] = tmpMean
      stdDevs[i, label] = tmpStdDev
    }
  }
  result = list()
  result$means = means
  result$stdDevs = stdDevs
  return(result)
}

calculateMeasnAndSDOfClusters <-function(data){
  labels = c( "av_goals",
              "av_goals_half_time",
              "av_shots",
              "av_shots_on_target",
              "av_corners",
              "av_fouls",
              "av_yellows",
              "av_reds",
              "av_shots_outside_target",
              "av_op_goals",
              "av_op_goals_half_time",
              "av_op_shots",
              "av_op_shots_on_target",
              "av_op_corners",
              "av_op_fouls",
              "av_op_yellows",
              "av_op_reds",
              "av_op_shots_outside_target")
  clusters = list()
  for(i in 1:13){
    tmp = data[[i]]
    clusters = append(clusters, unique(tmp$newCluster))
  }
  
  clusters = mixedsort(unique(unlist(clusters)))
  
  res = list()
  for(label in labels){
    means = data.frame(matrix(NA, ncol = length(clusters), nrow = 13))
    rownames(means) = 1:13
    colnames(means) = clusters
    stdDevs = data.frame(matrix(NA, ncol = length(clusters), nrow = 13))
    rownames(stdDevs) = 1:13
    colnames(stdDevs) = clusters
    
    tmpRes = list()
    for(i in 1:13){
      tmpData = data[[i]]
      for(clusterToCheck in clusters){
        mean = mean(tmpData[newCluster == clusterToCheck, get(label)])
        stdDev = sd(tmpData[newCluster == clusterToCheck, get(label)])
        means[i, clusterToCheck] = mean
        stdDevs[i, clusterToCheck] = stdDev
      }
    }
    
    tmpRes$means = means
    tmpRes$stdDevs = stdDevs
    res[[label]] = tmpRes
  }
  return(res)
}

getDistances <-function(data){
  data = data[complete.cases(data),]
  dataForClustering = getFilteredData(data)
  dataForClustering = data.frame(sapply(dataForClustering, normalize01))
  distances = dist(dataForClustering)
  return(distances)
}

estimatingNumberOfClusters <- function(data, alg){
  splitedData = splitDataToPeriods(data, 3)
  sil = rep(0, 13)
  df = as.data.frame(matrix(0, ncol = 13, nrow = 0))
  for(j in 5:20){
    set.seed(5)
    for(i in 1:13){
      tmp = splitedData[[i]]
      distances = getDistances(tmp)
      cl = clusteringOnePart(tmp, j, alg )
      sl = silhouette(cl$cluster, distances)
      sil[[i]] = mean(sl[,"sil_width"])
    }
    df = rbind(df, sil)
  }
  df = t(df)
  colnames(df) = 5:20
  rownames(df) = 1:13
  df = as.data.frame(df)
  return(df)
}

crossCorrelation <- function(val1, val2){
  cc = ccf(val1, val2, plot = FALSE)
  cc = cc[0]
  cc = unlist(cc)
  cc = cc["acf"]
  cc = as.numeric(cc)
  return(cc)
  
  if(length(val1) != length(val2)){
    stop("Different lenghts")
  }
  m1 = mean(val1)
  m2 = mean(val2)
  sd1 = sd(val1)
  sd2 = sd(val2)
  l1 = vector(mode="numeric", length=0)
  l2 = vector(mode="numeric", length=0)
  for(i in val1){
    tmp = (i - m1)/sd1
    l1 = append(l1, tmp)
  }
  
  for(i in val2){
    tmp = (i - m2)/sd2
    l2 = append(l2, tmp)
  }
  len = length(l1)
  mul = l1 * l2
  result = sum(mul)/(len-1)
  return(result)
}

calculateCrossCorrelations <- function(data){
  shotLabels = c( "home_shots_av10",
                  "away_shots_av10",
                  "diff_shots_av10")
  shotOnTargetLabels = c("home_shots_on_target_av10",
                         "away_shots_on_target_av10",
                         "diff_shots_on_target_av10")
  cornerLabels = c("home_corners_av10",
                   "away_corners_av10",
                   "diff_corners_av10")
  foulsLabels = c("home_fouls_av10",
                  "away_fouls_av10",
                  "diff_fouls_av10")
  yellowLabels = c("home_yellows_av10",
                   "away_yellows_av10",
                   "diff_yellows_av10")
  redLabels = c("home_reds_av10",
                "away_reds_av10",
                "diff_reds_av10")
  labels = list(shotLabels, shotOnTargetLabels, cornerLabels, 
             foulsLabels, yellowLabels, redLabels)
  res = list()
  for(tmpLabels in labels){
    label1 = tmpLabels[1]
    label2 = tmpLabels[2]
    
    tmp1 = lapply(data, function(x) mean(x[[label1]]))
    tmp2 = lapply(data, function(x) mean(x[[label2]]))
  
    tmp1$all = NULL
    tmp2$all = NULL
    
    tmp1 = unlist(tmp1)
    tmp2 = unlist(tmp2)
    
    cc = crossCorrelation(tmp1, tmp2)
    newName = paste(label1, label2, sep = "-")
    res[newName] = cc
    
  }
  return(res)
  
}

percentMean <-function(data, feature){
  min = lapply(KMclusteredData, function(x) min(x[[feature]]))
  max = lapply(KMclusteredData, function(x) max(x[[feature]]))
  mean = lapply(KMclusteredData, function(x) mean(x[[feature]]))
  min$all = NULL
  max$all = NULL
  mean$all = NULL
  max = unlist(max)
  min = unlist(min)
  mean = unlist(mean)
  
  res = (mean - min)/(max - min)
  return(res)
}

calculateKendallAndSpearmanPeriods <-function(importance){
  df = data.frame(periods= numeric(0), method = numeric(0), kendall= integer(0))
  for(i in 1:12){
    tmp1 = importance[[i]]
    tmp2 = importance[[i+1]]
    val = Kendall(tmp1$feature, tmp2$feature)
    val = val$tau
    val = val[[1]]
    df = rbind(df, list(i, 1, val))
  }
  
  for(i in 1:12){
    tmp1 = importance[[i]]
    tmp2 = importance[[i+1]]
    val = cor(as.numeric(tmp1$feature), 
              as.numeric(tmp2$feature), method = "spearman")
    df = rbind(df, list(i, 2, val))
  }
  colnames(df) = c("periods", "method", "correlation")
  
  df$method[df$method == 1] = "kendall"
  df$method[df$method == 2] = "spearman"
  df$periods = factor(paste(df$periods, df$periods + 1, sep = "-"), 
                      levels = c("1-2", "2-3", "3-4", "4-5", "5-6", "6-7", "7-8", "8-9", "9-10", "10-11", "11-12", "12-13"))
  return(df)
}

calculateKendallAndSpearmanAlg <-function(importance1, importance2){
  df = data.frame(period= numeric(0), method = numeric(0), kendall= integer(0))
  for(i in 1:13){
    tmp1 = importance1[[i]]
    tmp2 = importance2[[i]]
    val = Kendall(tmp1$feature, tmp2$feature)
    val = val$tau
    val = val[[1]]
    df = rbind(df, list(i, 1, val))
  }
  colnames(df) = c("period", "method", "correlation")
  
  for(i in 1:13){
    tmp1 = importance1[[i]]
    tmp2 = importance2[[i]]
    val = cor(as.numeric(tmp1$feature), 
              as.numeric(tmp2$feature), method = "spearman")
    df = rbind(df, list(i, 2, val))
  }
  
  df$method[df$method == 1] = "kendall"
  df$method[df$method == 2] = "spearman"
  return(df)
}

importanceAtK <- function(importance, k = 5){
  tmp = lapply(importance, function(x) as.data.frame(x)$feature[1:5])
  common = tmp[[1]]
  for(i in 2:13){
    t = tmp[[i]]
    common = intersect(common, t)
  }
  return(common)
}

meanAndSdOfImportance <- function(importance, places = FALSE){
  labels = c("av_shots", 
             "av_corners",
             "av_op_shots",
             "av_op_shots_outside_target",
             "av_shots_on_target",
             "av_op_corners",
             "av_shots_outside_target",
             "av_op_shots_on_target",
             "av_op_yellows",
             "av_reds",
             "av_op_reds",
             "av_op_fouls",
             "av_yellows",
             "av_fouls")
  if(places){
    importance = changeImportanceValuesToPostions(importance)
  }
  dt = data.table(importance = character(0), mean = numeric(0), sd = numeric(0))
  for(label in labels){
    values = sapply(importance, function(x) {
      x = as.data.frame(x)
      x$importance[x$feature == label]
    })
    dt = rbind(dt, data.table(importance = label, mean = mean(values), sd = sd(values)))
  }
  return(dt)
}

changeImportanceToLevels <- function(data, quantiles = TRUE){
  if(quantiles == TRUE){
    levels = quantile(data$importance, c(0.33, 0.66))
  }else{
    levels = c(0.33 * max(data$importance), 0.66 * max(data$importance))
  }
  data$levelOfImportance = factor(NA, levels = c("low", "medium", "high"))
  
  data$levelOfImportance[data$importance <= levels[1]] = "low"
  data$levelOfImportance[data$importance > levels[1] & data$importance <= levels[2] ] = "medium"
  data$levelOfImportance[data$importance > levels[2]] = "high"
  return(data)
}

calculateMovingAverage <-function(importance, size = 3, places = FALSE){
  if(places){
    importance = changeImportanceValuesToPostions(importance)
  }
  
  df = Reduce(function(x, y) {merge(x, y, by = "feature")}, importance)
  rownames(df) = df$feature
  df$feature = NULL
  df = t(apply(df, 1, function(x) ma(x, order = 3)))
  df = df[, !apply(is.na(df), 2, all)]
  colnames(df) = sapply(1:(ncol(df)), function(x) paste(x, x+2, sep = "-"))
  df = as.data.frame(df)
  return(df)
}

#'
#' highest importance has fisrt position
changeImportanceValuesToPostions <- function(importance){
  for(i in 1:length(importance)){
    importance[[i]]$importance = order(importance[[i]]$importance, decreasing = FALSE)
  }
  return(importance)
}

getImportanceLevels <- function(importance, quantiles = TRUE){
  for(i in 1:13){
    importance[[i]] = changeImportanceToLevels(importance[[i]], quantiles)
    or = order(importance[[i]]$feature)
    importance[[i]] = importance[[i]][or, ]
  }
  return(importance)  
}

getTableForLevel <- function(importanceLevels, level = "high"){
  tmp = sapply(importanceLevels, function(x) x[x$levelOfImportance == level, "feature"])
  return(table(unlist(tmp)))
}

calculateKendallAndSpearmanLevelsPeriods <- function(importance, quantiles = TRUE){
  for(i in 1:13){
    importance[[i]] = changeImportanceToLevels(importance[[i]], quantiles)
    or = order(importance[[i]]$feature)
    importance[[i]] = importance[[i]][or, ]
  }
  
  df = data.frame(periods= numeric(0), method = numeric(0), kendall= integer(0))
  for(i in 1:12){
    tmp1 = importance[[i]]
    tmp2 = importance[[i+1]]
    val = Kendall(tmp1$levelOfImportance, tmp2$levelOfImportance)
    val = val$tau
    val = val[[1]]
    df = rbind(df, list(i, 1, val))
  }
  
  for(i in 1:12){
    tmp1 = importance[[i]]
    tmp2 = importance[[i+1]]
    val = cor(as.numeric(tmp1$levelOfImportance), 
              as.numeric(tmp2$levelOfImportance), method = "spearman")
    df = rbind(df, list(i, 2, val))
  }
  colnames(df) = c("periods", "method", "correlation")
  
  df$method[df$method == 1] = "kendall"
  df$method[df$method == 2] = "spearman"
  df$periods = factor(paste(df$periods, df$periods + 1, sep = "-"), 
                      levels = c("1-2", "2-3", "3-4", "4-5", "5-6", "6-7", "7-8", "8-9", "9-10", "10-11", "11-12", "12-13"))
  
  return(df)
}

calculateKendallAndSpearmanLevelsAlg <-function(importance1, importance2, quantiles = TRUE){
  for(i in 1:13){
    importance1[[i]] = changeImportanceToLevels(importance1[[i]], quantiles)
    or = order(importance1[[i]]$feature)
    importance1[[i]] = importance1[[i]][or, ]
  }
  
  for(i in 1:13){
    importance2[[i]] = changeImportanceToLevels(importance2[[i]], quantiles)
    or = order(importance2[[i]]$feature)
    importance2[[i]] = importance2[[i]][or, ]
  }
  
  df = data.frame(period= numeric(0), method = numeric(0), kendall= integer(0))
  for(i in 1:13){
    tmp1 = importance1[[i]]
    tmp2 = importance2[[i]]
    val = Kendall(tmp1$levelOfImportance, tmp2$levelOfImportance)
    val = val$tau
    val = val[[1]]
    df = rbind(df, list(i, 1, val))
  }
  colnames(df) = c("period", "method", "correlation")
  
  for(i in 1:13){
    tmp1 = importance1[[i]]
    tmp2 = importance2[[i]]
    val = cor(as.numeric(tmp1$levelOfImportance), 
              as.numeric(tmp2$levelOfImportance), method = "spearman")
    df = rbind(df, list(i, 2, val))
  }
  
  df$method[df$method == 1] = "kendall"
  df$method[df$method == 2] = "spearman"
  return(df)
}

calculateFitFunction <- function(data, importance){
  colnames = importance$feature
  data$fit = 0
  importance$importance = normalize01(importance$importance)
  for(column in colnames){
    val = importance$importance[importance$feature == column]
    values = data[, column, with = FALSE]
    values = values * val
    data$fit = data$fit + values
  }
  return(data)
}

calculateFitFunctionsForAll <- function(newClusteredData, importance){
  for(i in 1:13){
    tmp = newClusteredData$data[[i]]
    im = importance[[i]]
    tmp = calculateFitFunction(tmp, im)
    newClusteredData$data[[i]] = tmp
  }
  return(newClusteredData)
}

getStatistics <- function(matches){
  features = c("home_goals","away_goals"               
               ,"home_goals_half_time","away_goals_half_time","home_shots"               
               ,"away_shots","home_shots_on_target","away_shots_on_target"     
               ,"home_corners","away_corners","home_fouls"               
               ,"away_fouls","home_yellows","away_yellows"             
               ,"home_reds","away_reds","home_shots_outside_target"
               ,"away_shots_outside_target", "home_pos", "away_pos")
  res = c()
  for(feature in features){
    min = round2(min(matches[[feature]]))
    max = round2(max(matches[[feature]]))
    mean = round2(mean(matches[[feature]]))
    sd = round2(sd(matches[[feature]]))
    median = round2(median(matches[[feature]]))
    
    line = paste(feature, min, mean, sd, median, max, sep = " & ")
    line = paste(line, " \\", sep = "")
    res = append(res, line)
    res = append(res,"\\hline")
  }
  res = paste(res, sep = "\n")
  print(res)
  
}

getMeansAndSdForFeaturesInSeasons <- function(matches){
  labels = c("home_shots",
             "away_shots",
             "home_shots_on_target",
             "away_shots_on_target",
             "home_shots_outside_target",
             "away_shots_outside_target",
             "home_corners",
             "away_corners",
             "home_fouls",
             "away_fouls",
             "home_yellows",
             "away_yellows",
             "home_reds",
             "away_reds",
             "home_goals",
             "away_goals",
             "home_goals_half_time",
             "away_goals_half_time")
  #matches = matches[labels]
  means = aggregate(matches[labels], by=list(matches$season_fk), FUN = mean)
  colnames(means)[1] = "season_fk"
  sd = aggregate(matches[labels], by=list(matches$season_fk), FUN = sd)
  colnames(sd)[1] = "season_fk"
  return(list(means = means, sd = sd))
}

getSizeAndSDOfCluster <-function(clusteredData){
  res = sapply(clusteredData, function(x){ table(x$cluster) })
  res = t(res)
  sd = sapply(clusteredData, function(x){ sd(table(x$cluster)) })
  res = cbind(res, sd)
  return(res)
}

calculateClustedDistribution <-function(clusteredData, tr){
  clustDistribution = as.data.frame(matrix(NA, ncol = nrow(tr$newTrRows), nrow = 13))
  
  for(i in 1:13){
    tmp = clusteredData[[i]]
    tab = table(tmp$newCluster)
    for(j in names(tab)){
      x = as.numeric(gsub("c", "", j))
      val = tab[[j]]
      clustDistribution[i, x] = val
    }
  }
  return(clustDistribution)
}


createLevelsStatistic <- function(importanceLevels){
  df = importanceLevels[[1]]
  df$levelOfImportance = as.numeric(df$levelOfImportance)
  df$importance = NULL
  colnames(df) = c("feature", "1")
  for (i in 2:13) {
    tmp = importanceLevels[[i]]
    tmp$levelOfImportance = as.numeric(tmp$levelOfImportance)
    tmp$importance = NULL
    colnames(tmp) = c("feature", as.character(i))
    df = merge(df, tmp, by = "feature")
  }
  rownames(df) = df$feature
  df$feature = NULL
  return(df)
}

calculateBelow <- function(splitedData){
  labels = c("av_shots", 
             "av_shots_on_target",
             "av_shots_outside_target",
             "av_corners",
             "av_fouls",
             "av_yellows",
             "av_reds",
             "av_op_shots",
             "av_op_shots_on_target",
             "av_op_shots_outside_target",
             "av_op_corners",
             "av_op_fouls",
             "av_op_yellows",
             "av_op_reds")
  dt = NULL
  for (i in 1:13){
    tmp = splitedData[[i]]
    row = numeric()
    for (label in labels) {
      m = mean(tmp[[label]])
      row = c(row, round2(prop.table(table(tmp[[label]] < m))[["TRUE"]] * 100))      
    }
    dt = rbind(dt, row)
  }
  rownames(dt) = 1:13
  colnames(dt) = labels
  return(dt)
}


getAverageAvPointsForClusterInPreiods <-function(newCLusterdeData){
  tmp = lapply(newCLusterdeData$data, function(tmp) aggregate(tmp$av_points, by = list(tmp$newCluster), mean))
  tmp2 = ldply(tmp)
  colnames(tmp2) = c("period", "cluster", "average_av_points")
  tmp2$period[tmp2$period == "00/01-02/03"] = 1
  tmp2$period[tmp2$period == "01/02-03/04"] = 2
  tmp2$period[tmp2$period == "02/03-04/05"] = 3
  tmp2$period[tmp2$period == "03/04-05/06"] = 4
  tmp2$period[tmp2$period == "04/05-06/07"] = 5
  tmp2$period[tmp2$period == "05/06-07/08"] = 6
  tmp2$period[tmp2$period == "06/07-08/09"] = 7
  tmp2$period[tmp2$period == "07/08-09/10"] = 8
  tmp2$period[tmp2$period == "08/09-10/11"] = 9
  tmp2$period[tmp2$period == "09/10-11/12"] = 10
  tmp2$period[tmp2$period == "10/11-12/13"] = 11
  tmp2$period[tmp2$period == "11/12-13/14"] = 12
  tmp2$period[tmp2$period == "12/13-14/15"] = 13
  
  return(tmp2)
}
