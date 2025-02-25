
###############################################
#         Loan Approval Project               #
#           Katarina I                        #
###############################################



#### 1. Introduction ####

# This is a capstone project of my choice for the final course in the HarvardX Professional Certificate in Data Science. 
# It uses a publicly available Kaggle dataset from a company that wants to automate the loan eligibility process based on customer details provided while filling online application form. 
# To automate this process, they have provided a partial dataset in order to identify the customers segments eligible for loan. The train set consists of 614 rows and 13 columns being:


if (!require(tidyverse)) install.packages('tidyverse')
library(tidyverse)
tab <- data.frame(Variable=c("Loan_ID",	"Gender",	"Married",	"Dependents",	"Education",	"Self_Employed",	"ApplicantIncome","CoapplicantIncome", "LoanAmount", "Loan_Amount_Term",	"Credit_History",	"Property_Area", "Loan_Status")	,
                  Description=c("Unique Loan ID", "Male/ Female", "Applicant married (Y/N)", "Number of dependents", "Applicant Education (Graduate/ Under Graduate)","Self employed (Y/N)", "Applicant income", "Coapplicant income","Loan amount in thousands", "Term of loan in months","credit history meets guidelines", "Urban/ Semi Urban/ Rural", "Loan approved (Y/N)"))
tab %>% knitr::kable()
rm(tab)


# For this binary classification problem (loan granted/not granted) four different machine learning algorithms will be used and model performance will be tested. 
# 
# This report is organized as follows:
#   
# 1. An introduction that summarizes the goal of the project.  
# 
# 2. The exploratory analysis section that includes data exploration and visualization, insights gained upon which different modeling approaches will be discussed
# 
# 3. Data preprocessing and feature engineering
# 
# 4. Modeling section that presents the models and discusses the model performance
# 
# 5. A conclusion section that gives a brief summary of the report, its limitations and future work




#### 2. Exploratory analysis ####

###### 2.1 Libraries and dowloading data ####

if (!require(tidyverse)) install.packages('tidyverse')
library(tidyverse)
if (!require(caret)) install.packages('caret')
library(caret)
if (!require(corrplot)) install.packages('corrplot')
library(corrplot)
if (!require(RColorBrewer)) install.packages('RColorBrewer')
library(RColorBrewer)
if (!require(rpart)) install.packages('rpart')
library(rpart)


# Dataset has been dowloaded from Kaggle through the following links:
 
# https://www.kaggle.com/altruistdelhite04/loan-prediction-problem-dataset?select=train_u6lujuX_CVtuZ9i.csv  train data

# https://www.kaggle.com/altruistdelhite04/loan-prediction-problem-dataset?select=test_Y3wMUE5_7gLdaTN.csv   test data


# Automated download is provided through GitHub:
test <- read.csv("https://raw.githubusercontent.com/eKInomics/Loan_prediction/main/test_Y3wMUE5_7gLdaTN.csv")
train <- read.csv("https://raw.githubusercontent.com/eKInomics/Loan_prediction/main/train_u6lujuX_CVtuZ9i.csv")




###### 2.2 First glimpse of the dataset ####

dim(train)

dim(test)

head(train)

head (test) 


# There si no outcome (Status_Loan) in the test set, so model performance will be evaluated on partitioned train set.
# We will rename the train dataset to "data"


rm(test)
data <- train
summary(data)



# Our dataset consists of 614 rows and 13 columns; outcome (Loan_Status) and 12 features:
# Loan_ID, Gender, Married, Dependents, Education, Self_Employed, ApplicantIncome, CoapplicantIncome, LoanAmount, Loan_Amount_Term, Credit_History, Property_Area)

# It appears to have some empty cells and NA's that we will have to deal with.
 
data[data==""] <- NA # replace empty cells with NA's

colSums(is.na(data))
sum(is.na(data)) 



# There are 149 missing values in our train dataset, the most in the credit history, followed by self employment, loan amounts, dependents...


str(data)


# There are 8 variables catogorized as categorical (some of them ordinal) and 5 numerical variables in the train set. 
# A numerical Credit_History variable (1/0) appears to have categorical characteristics hence will be factorized for the purposes of easier exploratory analyses. 


data$Credit_History <- as.factor(data$Credit_History)



###### 2.3 Data exploration and visualization ####


### Outcome 

prop.table(table(data$Loan_Status))%>%round(3)


# 68.7% of applicants in our dataset have been granted a loan

### Features

##### Categorical data


data %>%
  select(where(is.factor), -Loan_ID) %>%
  pivot_longer(-Loan_Status,names_to="Variable", values_to="Status")%>%
  group_by(Variable, Status, Loan_Status)%>%tally()%>%
  ggplot()+
  geom_col(aes(x=Status, y=n, fill=Loan_Status))+
  theme_bw()+
  facet_wrap(~Variable, scales="free_x", ncol=4)


# Visual inspection of the dataset shows that majority of applicants have credit history that meets the guidelines (1), have 0 dependents, 
# graduated, are male, married and employed (not self-employed) and live in a semiurban area. 
# Mode (most frequent value) will be used to replace NA's in this case.

# Some features make difference in probability of getting a loan. Let's have a closer look.


data %>%
  select(where(is.factor), -Loan_ID) %>%
  pivot_longer(-Loan_Status,names_to="Variable", values_to="Status")%>%
  group_by(Variable, Status)%>%count(Loan_Status)%>% 
  filter(!is.na(Status))%>%mutate(prop = prop.table(n))%>%
  ggplot(aes(x=Status, y=prop,fill=Loan_Status))+
  geom_col()+
  geom_text(aes(label = round(prop,2)),
            position = position_stack(vjust = .5))+
  theme_bw()+
  facet_wrap(~Variable, scales="free_x", ncol=4)


# It appears that applicants with appropriate credit history (1) are much more likely to get a loan. 
# More likely to be granted a loan are also those who have 2 dependants, graduates, married and with a semiurban property. 
# At first glimpse gender and employment status do not seem to be important in decision for loan approval

##### Numerical data

data %>%
  select(where(is.numeric))%>%summary()

# First, one can notice there are missing values in the variables Loan_Amount and Loan_Amount_Term.
# Summary statistics also shows that the average applicant's income is 5403, much higher than the average coapplicants income (1621). 
# Average loan amount is 146.4 (in thousands) and average Loan amount term is 342 months. 
# For the first three numerical features, mean is higher than the median, suggesting right-skewed distributions. 

# Let's look at the histograms (before NA's replaced):

data%>%select(ApplicantIncome, CoapplicantIncome, LoanAmount, Loan_Amount_Term, Loan_Status)%>%
  pivot_longer(-Loan_Status,names_to="Variable", values_to="Value")%>%
  ggplot()+
  geom_histogram(aes(x=Value))+
  facet_wrap(~Variable, scales="free_x", ncol=2)+
  theme_bw()



# log-transformations
data%>%select(ApplicantIncome, CoapplicantIncome, LoanAmount,  Loan_Status)%>%
  pivot_longer(-Loan_Status,names_to="Variable", values_to="Value")%>%
  ggplot()+
  geom_histogram(aes(x=log(Value)))+
  facet_wrap(~Variable, scales="free_x", ncol=2)+
  theme_bw()

# Histograms confirm right-skewed distributions of applicant and co-applicant income as well as loan amount. 
# There are also quite a lot of outliers in the features. 
# Median (less susspective to extreme values than mean) will be used to replace NA's in Loan_Amount (recall, there are no missing values in case of applicant's and coapplicant's income). 
# In case of Loan_Amount_Term 360 is by far the most frequent value and coincides with the median value.
#                               
# Let's check for any apparent relations between loan approval status and numerical variables


# Loan status vs incomes
data%>%select(ApplicantIncome, CoapplicantIncome, Loan_Status)%>%
  mutate(Income_together=ApplicantIncome+CoapplicantIncome)%>%
  pivot_longer(-Loan_Status,names_to="Variable", values_to="Income")%>%
  ggplot(aes(x=Variable, y=log(Income), fill=Loan_Status))+
  geom_boxplot()+
  theme_bw()


# Suprisingly, at first glimpse it seems that applicant's income does not affect chances of loan approvals. 
# Even more suprisingly, it appears that median coapplicants income is lower in cases where loan has been granted.
# We have therefore created a variable income_together, where incomes of both, applicant and co-applicant, are combined. 
# Yet, not even their income combined gives a strightforward evidence of its importance for prediction of loan status. 
                            
# Let's explore the loan amount


data%>%select(LoanAmount, Loan_Status)%>% filter(!is.na(LoanAmount))%>%
  ggplot(aes(x=Loan_Status, y=log(LoanAmount), fill=Loan_Status))+
  geom_boxplot()+
  theme_bw()

# There seems to be no straightforward relationship between loan amount and loan status. 
# This might be due to higher loan amounts requested from those with higher income and banks might be cautious about 
# their disposable income after loan payment. 
# We will explore correlations between pairs of variables and try to overcome this issues later 


#### 3. Data Preprocessing and feature engineering ####
###### 3.1 Imputing missing values ####

# Visual inspection in the prevoius section led us to believe that it would be a good call 
# to replace NA's with their mode for categorical and with their median for numerical variables.
                              
# Mode function defined 
Mode <- function(x) {
ux <- unique(x)
ux[which.max(tabulate(match(x, ux)))]
}    
                              
# replace NA's with their mode for categorical and with their median for numerical var.
                              
data<-data %>% select(-Loan_ID)%>% 
mutate_if(is.numeric, list(~replace(.,is.na(.), median(., na.rm = TRUE)))) %>%
mutate_if(is.factor, list(~replace(.,is.na(.), Mode(na.omit(.)))))
 
colSums(is.na(data)) # no more NA's
                              
###### 3.2 Encoding categorical features ####
                              
# Let's transform all categorical variables to numerical for easier use 


data <- data %>%
  mutate(Dependents = ifelse(as.character(Dependents) == "3+", 3, as.numeric(as.character(Dependents))),
  Gender_male=ifelse(Gender=="Male", 1, 0), # (Male=1, Female=0)
  Married_yes=ifelse(Married=="Yes", 1,0), # (Married =1, Not married =0)
  Education_graduate=ifelse(Education=="Graduate",1,0), #(Graduates = 1, Undergraduates=0)
  Self_Employed=ifelse(Self_Employed=="Yes", 1,0), # (Self-employed=1, Employed=0)
  Propery_Urban=ifelse(Property_Area=="Urban", 2, # (Urban=2, Semiurban=1, Rural=0)
                     ifelse(Property_Area=="Semiurban",1,0)),
  Loan_Status=ifelse(Loan_Status=="Y", 1, 0))%>% # (Loan approved= 1, Not approved=0)
  mutate(Credit_History=as.numeric(as.character(Credit_History)))%>%
  select(3, 5:10, 12:16)


str(data) 


###### 3.3 Correlation matrices ####

# Now let�s look at the correlations between the pairs of variables. 

cor_mat <- round(cor(data),2)

corrplot(cor_mat,       #  corrplot and RColorBrewer libraries used
         method="color", 
         col=brewer.pal(n=10, name="RdBu"),  
         addCoef.col = "black", # Add correlation coeff.
         tl.col="black", #Text label color
         tl.cex=0.6,
         number.cex=0.6) 
rm(cor_mat)


# As we have suspected from visual inspection, in terms of our target variable (Loan_Status) Credit_history has by far the largest coefficient of correlation. 
# It also proves that applicant's income doesn't correlate with loan status, 
# while coapplicants's income even shows negative correlation with loan status. 
# That might be because applicant's income is highly correlated to loan amount which in turn 
# is negatively correlated with loan status. This implies that creating new features that take this relations into account might be useful. 

###### 3.4 Creating new features ####

data_new <- data%>%
  mutate(Income_together=ApplicantIncome+CoapplicantIncome, 
         Monthly_payment=LoanAmount*1000/Loan_Amount_Term, # Loan amount is in thousands (multiply by 1000) and term is in months
         Disposable_income=Income_together-Monthly_payment, # Income after monthly payments 
         Disposable_income_per=Disposable_income/(Dependents+1))%>%   # Income per dependent person +1 for applicant
  select(-LoanAmount, -Loan_Amount_Term, -ApplicantIncome, -CoapplicantIncome, -Dependents,
         - Income_together, -Monthly_payment, -Disposable_income) # get rid off varibales incorporated in disposable income per person

cor_mat_2 <- round(cor(data_new),2)

corrplot(cor_mat_2, method="color", col=brewer.pal(n=10, name="RdBu"),  
         addCoef.col = "black", # Add correlation coeff.
         tl.col="black",
         tl.cex=0.6,
         number.cex=0.6)  


# We will proceed by performing log transformations on income variables


data_new_log <- data_new%>%
  filter(Disposable_income_per>=0)%>% # Get rid of negative values before log
  mutate(log_Disposable_income_per=log(Disposable_income_per))%>%
  select(-Disposable_income_per)

cor_mat_log <- round(cor(data_new_log),2)

corrplot(cor_mat_log, method="color", col=brewer.pal(n=10, name="RdBu"),  
         addCoef.col = "black", # Add correlation coeff.
         tl.col="black",
         tl.cex=0.6,
         number.cex=0.6)  
rm(list=c("cor_mat_2","cor_mat_log", "data_new"))



# After all the transformations, disposable income per person, which shows how much
# income per person a household is left after paying for loan, still shows no correlation with loan status. 

#### 4. Modeling ####

# We will use 2 different datasets for modelling:
# 
#     a) data, where only necessary imputations of missing values were performed
#     
#     b) data_new_log, where more feature engineering has been done. We have created new variables and made log transformations.
#     
# Models will be evaluated on both datasets.

###### 4.1 Partitioning ####

# Because of the lack of target (outcome) variable in the original Keggle test set, we will partition the data which was originally tagged as the train. 
# 20% of data will be used as test set and remaining 80% as train set 

 # a) "Data" : with only necessary imputations of missing values performed

# change target back to more intuitive (1=Y, 0=N)
data<-data%>%
  mutate(Loan_Status=ifelse(Loan_Status==1,"Y","N")) 

set.seed(3, sample.kind = "Rounding")

#partition on Loan_Status
test_index <- createDataPartition(data$Loan_Status, times = 1, p = 0.2, list = FALSE)   
test_set <- data[test_index, ]# Assign the 20% partition to test_set and 
train_set <- data[-test_index, ] # the remaining 80% partition to train_set

dim(test_set) #check dimensions
dim(train_set)
mean(test_set$Loan_Status=="Y") # check means
mean(train_set$Loan_Status=="Y")



# b) "Data_new_log" : new variable out of existing (which were omitted) + log transformation

data_new_log<-data_new_log%>%
  mutate(Loan_Status=ifelse(Loan_Status=="1","Y","N"))

set.seed(9, sample.kind = "Rounding")
#partition on Loan_Status
test_index <- createDataPartition(data_new_log$Loan_Status, times = 1, p = 0.2, list = FALSE)  

test_set_2 <- data_new_log[test_index, ]# Assign the 20% partition to test_set and 
train_set_2 <- data_new_log[-test_index, ] # the remaining 80% partition to train_set

dim(test_set_2) #check dimensions
dim(train_set_2)
mean(test_set_2$Loan_Status=="Y") # check means
mean(train_set_2$Loan_Status=="Y")


# One can notice that datasets are of somewhat different dimensions. 
# We have created new variables out of existing ones in the data_new_log, hence those were no longer needed. 
# Additionally, we have lost 2 observations due to log transformation. 

 
# Both train and test set seem to have similar proportions of those who have been granted loans 

###### 4.2  Models ####

# We will make predictions based on the following models:
# 
#    1. Simple model using credit history only
#    
#    2. Logistic regression
#    
#    3. KNN
#    
#    4. Decision tree
#    
#    5. Random forest
# 
# First, we will train the algorithms on the train_set, a partion of the "data" that was treated only for the missing values. Values will be predicted by different ML algorithms on the test_set and model performance discussed (a)
# 
# Then everything will be repeated on the train_set_2 and test_set_2, partions of the "data_new_log" dataset  where additional feature engineering has been performed (b)


train_set$Loan_Status <- as.factor(train_set$Loan_Status) #convert outcome to factor
test_set$Loan_Status <- as.factor(test_set$Loan_Status)

train_set_2$Loan_Status <- as.factor(train_set_2$Loan_Status)
test_set_2$Loan_Status <- as.factor(test_set_2$Loan_Status)


# Before we start, let's create matrix for performance metrics
                              
                              
                  
 # a)
metric = matrix(rep(0), nrow=4, ncol=4) 
colnames(metric )<- c('Accuracy', 'Sensitivity', 'Specificity', 'F1')
rownames(metric) <- c('Simple model with credit_history', 'Logistic regression', 
                                                    'kNN', "Decision tree")
                              
# b)
                              
metric_2 = matrix(rep(0), nrow=4, ncol=4)  
colnames(metric_2)<- c('Accuracy', 'Sensitivity', 'Specificity', 'F1')
rownames(metric_2) <- c('Simple model with credit_history', 'Logistic regression', 
                                                      'kNN', "Decision tree")
                             
######## 4.2.1. Simple model using credit history only ####
                              
# Previously we have seen that credit history seems to be an important feature in loan approval prediction. 
# We will therefore train a very simple model, where credit history is the only predictor.
                              
# a) 
train_simple <- train(Loan_Status ~ Credit_History, 
                      method="glm", 
                      family = "binomial", 
                      data= train_set)

cm <- confusionMatrix(data = predict(train_simple, test_set), 
                      reference = test_set$Loan_Status)
cm

metric[1,2:4] <-round(cm$byClass[c("Sensitivity","Specificity","F1")],3)
metric[1,1] <-round(cm$overall["Accuracy"],3)
metric[1,]
 

# b) 

train_simple_2 <- train(Loan_Status ~ Credit_History, 
                        method="glm", 
                        family = "binomial", 
                        data= train_set_2)

cm_2 <- confusionMatrix(data = predict(train_simple_2, test_set_2), 
                        reference = test_set_2$Loan_Status)

metric_2[1,2:4] <-round(cm_2$byClass[c("Sensitivity","Specificity","F1")],3)
metric_2[1,1] <-round(cm_2$overall["Accuracy"],3)
metric_2[1,]



# This simple model that uses credit history as the only predictor shows relatively high accuracy.
# This is possible despite low sensitivity and is due to low prevalence: the proportion of loans not granted (Loan_Status=N, N being our Positive class) is relatively low. 
# Failing to predict loan granted when it actually hasn't been granted (low sensitivity) does not lower the accuracy as much as failing to predict loans granted when actual loans were granted (low specificity). 
# There are 2 measures of model performance that overcome the issues of highly imbalanced data  (balanced accuracy and F1 score). We will pay  extra attention to sensitivity and F1 score in the rest of this project.



### 4.2.2. Logistic regression 

# Now we will try logistic regression using all the predictors in the dataset.
# Logistic regression provides an alternative to linear regression for binary classification problems. 


# a) 


train_glm <- train(Loan_Status ~ ., 
                   method="glm", 
                   family = "binomial", 
                   trControl = trainControl(method = "cv", number = 5),
                   data= train_set)

summary(train_glm)


cm <- confusionMatrix(data = predict(train_glm, test_set), 
                reference = test_set$Loan_Status)

metric[2,2:4] <-round(cm$byClass[c("Sensitivity","Specificity","F1")],3)
metric[2,1] <-round(cm$overall["Accuracy"],3)
metric[1:2,]



# b) 


train_glm_2 <- train(Loan_Status ~ ., 
                     method="glm", 
                     family = "binomial", 
                     trControl = trainControl(method = "cv", number = 5),
                     data= train_set_2)

cm_2 <-confusionMatrix(data = predict(train_glm_2, test_set_2), 
                reference = test_set_2$Loan_Status)

metric_2[2,2:4] <-round(cm_2$byClass[c("Sensitivity","Specificity","F1")],3)
metric_2[2,1] <-round(cm_2$overall["Accuracy"],3)
metric_2[1:2,]


# Logistic regression performance didn't improve w.r.t simple model, Credit_History is in both cases decisive feature


###### 4.2.3. K-nearest neighbors ####

# a)


set.seed(9, sample.kind = "Rounding")
train_knn <- train(Loan_Status ~ ., method="knn", 
                   preProcess = c("center","scale"),
                   data= train_set, 
                   tuneGrid=data.frame(k = seq(1, 30, 2)))
train_knn$bestTune
ggplot(train_knn, highlight = T)+
  theme_bw()



cm <- confusionMatrix(data = predict(train_knn, test_set, type="raw"), 
                      reference = test_set$Loan_Status)

metric[3,2:4] <-round(cm$byClass[c("Sensitivity","Specificity","F1")],3)
metric[3,1] <-round(cm$overall["Accuracy"],3)
metric[1:3,]


# b)
set.seed(9, sample.kind = "Rounding")

train_knn_2 <- train(Loan_Status ~ ., 
                     method="knn", 
                     data= train_set_2, 
                     preProcess = c("center","scale"),
                     tuneGrid=data.frame(k = seq(1, 30, 2)))

train_knn_2$bestTune

ggplot(train_knn_2, highlight = T)+
  theme_bw()
#The best performing model is 27-nearest neighbor model

cm_2 <- confusionMatrix(data = predict(train_knn_2, test_set_2, type="raw"), 
                        reference = test_set_2$Loan_Status)

metric_2[3,2:4] <-round(cm_2$byClass[c("Sensitivity","Specificity","F1")],3)
metric_2[3,1] <-round(cm_2$overall["Accuracy"],3)
metric_2[1:3,]

# In both cases kNN models perform somewhat worse than logistic regression. Even after tuning we haven't been able to increase none of our selected performance measures (accuracy, sensitivity, specificity, F1) above those of logistic regression.


###### 4.2.4. Decision tree ####

# Decision trees form predictions by calculating which class is the most common among the training set observations within the partition.
# They are easy to interpret and visualize and they can  model human decision processes, which loan approval could be seen as. However the approach via recursive partitioning can easily over-train.

 # a)

fit <- rpart(Loan_Status ~ ., data = train_set) 

# visualize the splits 
plot(fit, margin=0.1)
text(fit, cex = 0.75)


pred <- predict(fit, test_set, type="class")%>%factor()
cm<-confusionMatrix(pred, test_set$Loan_Status)

metric[4,2:4] <- round(cm$byClass[c("Sensitivity","Specificity","F1")],3)
metric[4,1]<-round(cm$overall["Accuracy"],3)
metric[1:4,]


# First decision tree splits at marriage status and loan amount, in addition to credit history. 
# However, it's performance is lower compared to previous models.

# We will now use cross validation to choose cp. We allow for very marginal improvement

train_rpart <- train(Loan_Status ~ ., 
                     method = "rpart", 
                     tuneGrid = data.frame(cp = seq(0.0, 0.007, len = 25)), 
                     data = train_set)

plot(train_rpart$finalModel)
text(train_rpart$finalModel, cex = 0.75)

cm <- confusionMatrix(data = predict(train_rpart, test_set), 
                      reference = test_set$Loan_Status)

metric[4,2:4] <- round(cm$byClass[c("Sensitivity","Specificity","F1")],3)
metric[4,1] <- round(cm$overall["Accuracy"],3)
metric[1:4,]

# Adding complexity (additional splitting by coapplicant and applicant income) improves one important aspect of performance (sensitivity), while F1 stays similar and accuracy even lower. Among decision trees this one is chosen.
# Apart from sensitivity, it underperforms with respect to prevoius models (Simple, Logistic regression, kNN).  

cm_tr <-confusionMatrix(data = predict(train_rpart, train_set), 
                        reference = train_set$Loan_Status)

round(cm_tr$byClass[c("Sensitivity","Specificity","F1")],3)
round(cm_tr$overall["Accuracy"],3)

# no signs of over-training



# b)

fit <- rpart(Loan_Status ~ ., data = train_set_2) 

# visualize the splits 
plot(fit, margin=0.1)
text(fit, cex = 0.75)

# First model gives us credit history as the only split. 
# Not suprisingly, performance is similar to simple model using credit history only and logistic regression. 



pred <- predict(fit, test_set_2, type="class")%>%factor()
cm_2<-confusionMatrix(pred, test_set_2$Loan_Status)

metric_2[4,2:4] <- round(cm_2$byClass[c("Sensitivity","Specificity","F1")],3)
metric_2[4,1] <- round(cm_2$overall["Accuracy"],3)
metric_2[1:4,]


# We have tried the most common parameters used for partition decision: the complexity parameter (cp) 
# and the minimum number of observations required in a partition before partitioning it further (minsplit in the rpart package). The latter shows no difference compared to the baseline so only cp tuning is presented

# We will now use cross validation to choose cp. We allow for very marginal improvement

train_rpart_2 <- train(Loan_Status ~ ., 
                       method = "rpart", 
                       tuneGrid = data.frame(cp = seq(0.0, 0.007, len = 25)), 
                       data = train_set_2)

plot(train_rpart_2$finalModel)
text(train_rpart_2$finalModel, cex = 0.75)


cm_2 <- confusionMatrix(data = predict(train_rpart_2, test_set_2), 
                        reference = test_set_2$Loan_Status)

round(cm_2$byClass[c("Sensitivity","Specificity","F1")],3)
round(cm_2$overall["Accuracy"],3)



# Even by increasing it's complexity, model performance is not good.





#### 5. Conclusion 

# This project is based on publicly available Kaggle dataset from a company that wants to automate the loan eligibility process. 
# Dataset consists of 614 observations, outcome (Loan_Status) and 12 features. Some of them (apart from loanID, also gender, employment status ...) seem not to be decisive for the loan approval, while on the other hand credit history is the most important feature across all the models analyzed. 

# Data was trained with four different models:
# 
#    1. simple model using credit history as the only predictor
#    
#    2. logistic regression
#    
#    3. kNN
#    
#    4. decision tree
#   
# All the accuracies of predicted outcomes w.r.t. true values in the test set were well above 80% for not engineered dataset - cases (a). 
# However, all the models were somehow weak in sensitivity (predicted loan granted when true value is loan not granted). 
# Due to low prevalance this didn't affect accuracies as much, while computed balanced accuracies and F1 scores were much lower.

# Feature engineering has also been performed and models based on the modified dataset evaluated, 
# but their performance didn't improve compared to the original dataset, where only imputations of missing values have been treated.


metric%>%knitr::kable()


#  Final choice of model isn't staightforward. Decision tree improves on sensitivity compared to logistic regression. 
# Some types of errors are more costly than the others, and granting a loan to someone that is unable to repay  is one of them.
# On the other hand, decision trees are not very flexible and highly unstable to changes in training data. 
# Given that and the fact that logistic regression outperformed decision tree in terms of accuracy and F1, I have finally chosen logistic regression. 
# Its performance metrics are identical to those of the simple model that uses credit history as the only predictor, 
# as credit history is by far the most predictive variable out of all the available features, but marriage status seems to have statistically significant effect 
# as well and its flexiblity could prove important in case additional observations could be obtained.
# 
# In the future random forest, which can improve some of the shortcomings of decision trees, should be evaluated, 
# as well as some tunings of logistic regression in direction of putting more weight to sensitivity could be performed.

# Yet, it is also quite likely that not all the important features are available in the dataset. 
# Since by far the most frequent loan amount term in the dataset is 30 years (360 months), applicants' age could be an important feature, 
# besides other properties owned by applicants, type of job contract (permanent/temporary), to name just few. 
# There are also numerous outliers that might be useful to treat, eventhough our dataset isn't large. 
# Generally speaking, having been able to have more observations would most probably improve model performance. 
