source("core/utils.R")
source("core/databaseConnector.R")
library("data.table")

getData <- function(){
  results = readTableFromMatches()
  
  results$date = results$match_date
  
  seasons = readDataFromDatabase("Seasons")
  results$seasonStart = with(seasons, startDate[match(results$season_fk, idSeasons)])
  results$seasonEnd = with(seasons, endDate[match(results$season_fk, idSeasons)])
  results$date = as.Date(results$date)
  results$seasonStart = as.Date(results$seasonStart)
  results$seasonEnd = as.Date(results$seasonEnd)
  results$day_of_season = results$date - results$seasonStart
  
  #results$date = NULL
  results$seasonStart = NULL
  results$seasonEnd = NULL
  
  results = separate(data = results, col = match_date, into = c("year", "month", "day"), sep = "-")
  results = results[ results$league_fk ==2 & results$season_fk >= 8, ]
  results = results[order(results$year, results$month, results$day),]
  results = Filter(function(x) !any(is.na(x)), results)
  rownames(results) = 1:nrow(results)
  results$idMatch = 1:nrow(results)
  
  
  
  for(i in 8:22){
    tmp = results[ results$season_fk ==i,]
    tmp = addTablePlace(tmp)
    results$home_pos[ results$season_fk ==i] = tmp$home_pos
    results$away_pos[ results$season_fk ==i] = tmp$away_pos
  }
  results$season_fk <- with(seasons,  name[match(results$season_fk, idSeasons)])
  results$result = factor(results$result, levels = c("H", "D", "A"))
  
  return(results)
}

createRow <- function(data, isHome = TRUE, club, isFirst = TRUE){
  newData = data.table("team" = club)
  newData$type = ifelse(isHome, "home", "away")
  newData$season = unique(data$season_fk)[1]
  newData$round = ifelse(isFirst, 1, 2)
  sufixes = c("goals",
              "goals_half_time",
              "shots",
              "shots_on_target",
              "corners",
              "fouls",
              "yellows",
              "reds" ,
              "shots_outside_target")
  labels = sufixes
  oponentLabels = sufixes
  if(isHome){
    data = data[data$home_team_fk == club,]
    labels = paste("home", sufixes, sep = "_")
    oponentLabels = paste("away", sufixes, sep = "_")
  }
  else{
    data = data[data$away_team_fk == club,]
    labels = paste("away", sufixes, sep = "_")
    oponentLabels = paste("home", sufixes, sep = "_")
  }
  
  newData$matches = nrow(data)
  
  summary = data[, labels]
  summary = colMeans(summary)
  summary = as.data.table(t(summary))
  setnames(summary, colnames(summary), paste("av", sufixes, sep = "_") )
  
  oponentSummary = data[, oponentLabels]
  oponentSummary = colMeans(oponentSummary)
  oponentSummary = as.data.table(t(oponentSummary))
  setnames(oponentSummary, colnames(oponentSummary), paste("av", "op", sufixes, sep = "_") )
  
  newData = cbind(newData, summary, oponentSummary)
  newData$wins =  ifelse(!is.na(table(data$result)["H"]), table(data$result)["H"], 0)
  newData$draws = ifelse(!is.na(table(data$result)["D"]), table(data$result)["D"], 0)
  newData$loses = ifelse(!is.na(table(data$result)["L"]), table(data$result)["L"], 0)
  if(!isHome){
    tmp = newData$wins
    newData$wins = newData$loses
    newData$loses = tmp
  }
  return(newData)
}

prepareDataForClassification <- function(data){
  newData = data.table()
  seasons = unique(data$season_fk)
  for(season in seasons){
    tmpData = data[ data$season_fk == season,]
    clubs = unique(tmpData$home_team_fk)
    firstRound = tmpData[1:190, ]
    secondRound = tmpData[191:380, ]
    for(club in clubs){
      homeF = createRow(firstRound, isHome = TRUE, club, TRUE)
      awayF = createRow(firstRound, isHome = FALSE, club, TRUE)
      homeS = createRow(secondRound, isHome = TRUE, club, FALSE)
      awayS = createRow(secondRound, isHome = FALSE, club, FALSE)
      
      newData = rbind(newData, homeF, awayF, homeS, awayS)
    }
    
  }
  
  
  newData$av_points = (newData$wins * 3 + newData$draws) / newData$matches
  newData$av_op_points = (newData$loses * 3 + newData$draws) / newData$matches
  newData = updateTablePlace(newData)
  
  newData$id = 1:nrow(newData)
  
  
  
  
#   newData = data.frame(  data$idMatch )
#   setnames(newData, "data.idMatch", "idMatch")
#   newData$season_fk = as.factor(data$season_fk) 
#   newData$home_team_fk = as.factor(data$home_team_fk) 
#   newData$away_team_fk = as.factor(data$away_team_fk)
#     
#   newData$home_pos = as.integer(data$home_pos) 
#   newData$away_pos = as.integer(data$away_pos)
#   
#   newData$home_couch_fk = as.factor(data$home_couch_fk) 
#   newData$away_couch_fk = as.factor(data$away_couch_fk)
#   
#   newData$day_of_season = as.integer(data$day_of_season)
#   newData$date = data$date
#   newData$year = as.integer(data$year) 
#   newData$month = as.integer(data$month) 
#   newData$day = as.integer(data$day) 
#   
#   seasons = unique
#   attributes = c("goals", "goals_half_time", "shots", "shots_on_target",
#                "corners", "fouls", "yellows", "reds")
#   
#   for(attr in attributes){
#     attrName = paste("home_", attr,"_av10", sep="")
#     newData[[attrName]] = as.numeric(sapply(data$idMatch, function(x) getMean(x, data, attr)))
#     attrName2 = paste("away_", attr,"_av10", sep="")
#     newData[[attrName2]] = as.numeric(sapply(data$idMatch, function(x) getMean(x, data, attr, forWho = "away")))
#     attrName3 = paste("diff_", attr,"_av10", sep="")
#     newData[[attrName3]] = as.numeric(newData[[attrName]] - newData[[attrName2]])
#   }
#   
#   newData$result = as.factor(data$result) 
#   
#   #newData$idMatch = NULL
#   
#   newData$month = newData$month - 7
#   newData$month[newData$month < 0] = newData$month[newData$month < 0] + 12
  return(newData)
}

updateTablePlace <- function(data){
  data$leaguePosition = factor(NA, levels = c("top", "medium", "bottom"))
  for(season in unique(data$season)){
    q = quantile(data$av_points[data$season == season], c(0.33, 0.66))
    data$leaguePosition[ data$season == season & data$av_points < q[1]] = "bottom"
    data$leaguePosition[ data$season == season & between(data$av_points, q[1], q[2]) ] = "medium"
    data$leaguePosition[ data$season == season & data$av_points > q[2] ] = "top"
  }
  return(data)
}

getPreviosuMatchesOfTeam <- function(idMatch, data, howManyPreviousMatches = 10, 
                                     forWho = "home"){
  thisMatch = data[ data$idMatch == idMatch,]
  matchId = thisMatch$idMatch
  clubId = NA
  
  if(forWho == "home"){
    clubId = thisMatch$home_team_fk
  }
  else if(forWho == "away"){
    clubId = thisMatch$away_team_fk
  }else{
    stop("You must specify fow who I should searching")
  }
  
  data = data[ data$idMatch < matchId,]
  if(forWho == "home"){
    data = data[data$home_team_fk == clubId,]
  }
  else if(forWho == "away"){
    data = data[data$away_team_fk == clubId,]
  }
  data = data[data$home_team_fk == clubId | data$away_team_fk == clubId,]
  
  return(tail(data, howManyPreviousMatches))
}

getMean <- function(id, data, columnName, howManyPreviousMatches = 10, forWho = "home"){
  thisMatch = data[ data$idMatch == id,]
  matchId = thisMatch$idMatch
  clubId = NA
  
  if(forWho == "home"){
    clubId = thisMatch$home_team_fk
  }
  else if(forWho == "away"){
    clubId = thisMatch$away_team_fk
  }else{
    stop("You must specify fow who I should searching")
  }
  
  tmp = getPreviosuMatchesOfTeam(id, data, howManyPreviousMatches, forWho)
  home = tmp[tmp$home_team_fk == clubId,] 
  away = tmp[tmp$away_team_fk == clubId,] 
  
  homeName = paste("home_", columnName, sep = "")
  awayName = paste("away_", columnName, sep = "")
  values = c(home[[homeName]], away[[awayName]])
  return(mean(values))
}

addTablePlace <-function(data){
  data$home_pos = 0
  data$away_pos = 0

  leagueTable = data.table(pos = 1:20, team = unique(data$home_team_fk), p =0, win = 0,
                           draw = 0, lose = 0, gf = 0, ga = 0, gd = 0, point = 0)
  leagueTable = leagueTable[order(leagueTable$team),]  
  leagueTable$pos = 1:20
  lastDay = data$day[1]
  matchesToCount = c()
  
  for(i in data$idMatch){
    match = data[ data$idMatch == i,]
    if(match$day == lastDay){
      matchesToCount = c(matchesToCount, list(match))
    }
    else{
      #TODO do it better (export to other function)
      leagueTable = updateLeagueTable(leagueTable, matchesToCount)
      
      matchesToCount = c(list(match))
      lastDay = match$day
      
    }
    
    
    data$home_pos[ data$idMatch == i] = leagueTable$pos[ leagueTable$team == match$home_team_fk]
    data$away_pos[ data$idMatch == i] = leagueTable$pos[ leagueTable$team == match$away_team_fk]
  }
  leagueTable = updateLeagueTable(leagueTable, matchesToCount)
  
  return(data)
}

getTableForSeason <- function(data){
  leagueTable = data.table(pos = 1:20, team = unique(data$home_team_fk), p =0, win = 0,
                           draw = 0, lose = 0, gf = 0, ga = 0, gd = 0, point = 0)
  leagueTable = leagueTable[order(leagueTable$team),]  
  leagueTable$pos = 1:20
  lastDay = data$day[1]
  matchesToCount = c()
  
  for(i in data$idMatch){
    match = data[ data$idMatch == i,]
    if(match$day == lastDay){
      matchesToCount = c(matchesToCount, list(match))
    }
    else{
      #TODO do it better (export to other function)
      leagueTable = updateLeagueTable(leagueTable, matchesToCount)
      
      matchesToCount = c(list(match))
      lastDay = match$day
      
    }
  }
  leagueTable = updateLeagueTable(leagueTable, matchesToCount)
  
  return(leagueTable)
}


getAllTables <-function(data){
  tables = list()  
  for(key in unique(data$season_fk)){
    tmp = data[data$season_fk == key, ]
    table = getTableForSeason(tmp)
    tables[[key]] = table
  }
  return(tables)
}

getPlaces <- function(matches){
  tables =  getAllTables(matches)
  teams = unique(matches$home_team_fk)
  res = data.table(matrix(ncol = 16, nrow = 0))
  colnames(res) = c("team", names(tables))
  for(team in teams){
    places = list(team = team)
    for(season in names(tables)){
      table = tables[[season]]
      place = table$pos[table$team == team]
      if(length(place) == 0){
        places[season] = NA
      }
      else{
        places[season] = place
      }
    }
    # places = as.list(places)
    res = rbind(res, places)
  }
  return(res)
}


updateLeagueTable <-function(leagueTable, matchesToCount){
  for(savedMatch in matchesToCount){
    leagueTable$p[ leagueTable$team == savedMatch$home_team_fk] = leagueTable$p[ leagueTable$team == savedMatch$home_team_fk] + 1
    leagueTable$p[ leagueTable$team == savedMatch$away_team_fk] = leagueTable$p[ leagueTable$team == savedMatch$away_team_fk] + 1
    
    leagueTable$gf[ leagueTable$team == savedMatch$home_team_fk] = leagueTable$gf[ leagueTable$team == savedMatch$home_team_fk] + savedMatch$home_goals
    leagueTable$gf[ leagueTable$team == savedMatch$away_team_fk] = leagueTable$gf[ leagueTable$team == savedMatch$away_team_fk] + savedMatch$away_goals
    leagueTable$ga[ leagueTable$team == savedMatch$home_team_fk] = leagueTable$ga[ leagueTable$team == savedMatch$home_team_fk] + savedMatch$away_goals
    leagueTable$ga[ leagueTable$team == savedMatch$away_team_fk] = leagueTable$ga[ leagueTable$team == savedMatch$away_team_fk] + savedMatch$home_goals
    
    if(savedMatch$result == "H"){
      leagueTable$win[ leagueTable$team == savedMatch$home_team_fk] = leagueTable$win[ leagueTable$team == savedMatch$home_team_fk] + 1
      leagueTable$lose[ leagueTable$team == savedMatch$away_team_fk] = leagueTable$lose[ leagueTable$team == savedMatch$away_team_fk] + 1
      leagueTable$point[ leagueTable$team == savedMatch$home_team_fk] = leagueTable$point[ leagueTable$team == savedMatch$home_team_fk] + 3
    }
    else if(savedMatch$result == "A"){
      leagueTable$win[ leagueTable$team == savedMatch$away_team_fk] = leagueTable$win[ leagueTable$team == savedMatch$away_team_fk] + 1
      leagueTable$lose[ leagueTable$team == savedMatch$home_team_fk] = leagueTable$lose[ leagueTable$team == savedMatch$home_team_fk] + 1
      leagueTable$point[ leagueTable$team == savedMatch$away_team_fk] = leagueTable$point[ leagueTable$team == savedMatch$away_team_fk] + 3
    }
    else{
      leagueTable$draw[ leagueTable$team == savedMatch$away_team_fk] = leagueTable$draw[ leagueTable$team == savedMatch$away_team_fk] + 1
      leagueTable$draw[ leagueTable$team == savedMatch$home_team_fk] = leagueTable$draw[ leagueTable$team == savedMatch$home_team_fk] + 1
      leagueTable$point[ leagueTable$team == savedMatch$home_team_fk] = leagueTable$point[ leagueTable$team == savedMatch$home_team_fk] + 1
      leagueTable$point[ leagueTable$team == savedMatch$away_team_fk] = leagueTable$point[ leagueTable$team == savedMatch$away_team_fk] + 1
    }
  }
  leagueTable$gd =leagueTable$gf - leagueTable$ga 
  leagueTable = leagueTable[order(leagueTable$point, leagueTable$gd, decreasing = TRUE),] 
  leagueTable$pos = 1:20
  return(leagueTable)
}

jaccardIndex <-function(vec1, vec2){
  n1 = length(vec1)
  n2 = length(vec2)
  ni = length(intersect(vec1, vec2))
  return(ni/(n1 + n2 - ni))
}

lengthOfIntersect <- function(vec1, vec2){
  ni = length(intersect(vec1, vec2))
  return(ni)
}


