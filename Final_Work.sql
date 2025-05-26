#1 Запрос для получения списка клиентов с непрерывной историей за год

With MonthlyTransactions AS (
   Select
       Id_client,
       Date_Format( date_new, '%Y - %m - 01') transaction_month,
       Count(*) AS monthly_count,
       Sum(Sum_payment) AS monthly_sum
   From
       transactions
   Where
       date_new>= '2015-06-01' AND date_new < '2016-06-01'
   Group by
       Id_client, transaction_month
),
ClientActivity AS (
    Select
        Id_client,
        Count(Distinct transaction_month) AS active_month,
        SUM(monthly_count) AS total_operations,
        AVG(monthly_sum) As average_check,
        SUM(monthly_sum) AS total_amount
	From
        MonthlyTransactions
	Group by 
        Id_client
)
Select
    c.ID_client,
	ca.total_operations,
    ca.average_check,
    ca.total_amount
From
    customers c
Join
    clientActivity ca ON c.ID_client=ca.Id_client
Where
    ca.active_months = 12;    

# Запрс для получения средней суммы покупок за месяц
 Select
      ID_client,
      AVG(monthly_sum) AS average_monthly_spending
 From
     (
      Select
		   ID_client,
           DATE_FORMAT(date_new, '%Y - %m-01') AS transaction_month,
           Sum(Sum_payment) AS monthly_sum
	  From
           transactions
	  Where
           date_new >= '2015-06-01' And date_new < '2016-06-01'
	  Group by
           ID_client, transaction_month
	) AS MonthlySums
Group by
    ID_client;
    
    # Запрос для получения количества всех операций по клиенту за период
Select
    ID_client,
    Count(*) AS total_operations
From
    transactions
Where
    date_new>= '2015-06-01' AND date_new < '2016-06-01'
Group by
    ID_client;
    
    #2  Информация в разрезе месяцев
    # a) средняя сумма чека в месяц
   Select
	DATE_FORMAT(date_new, '%Y - %m') AS transaction_month,
    AVG(Sum_payment) AS average_check
From
    transactions
Where
    date_new>= '2015-06-01' AND date_new < '2016-06-01'
Group by
    transaction_month
Order by transaction_month;


#b) Среднее количество операций в месяц
Select
    DATE_FORMAT(date_new, '%Y - %m') AS transaction_month,
    Count(Id_check) AS total_operations,
    AVG(Count(Id_check)) OVER () AS average_operations_per_month
From transactions
Where
	 date_new>= '2015-06-01' AND date_new < '2016-06-01'
Group by 
     transaction_month
Order by
     transaction_month;

#С) Среднее количество клиентов которые совершали операций
Select
	DATE_FORMAT(t.date_new, '%Y - %m') As transaction_month,
    Count(Distinct t.ID_client) AS total_clients,
    AVG(Count(Distinct t.ID_client)) OVER () AS average_clients_per_month
From
    transactions t
Where
    t.date_new >= '2015-06-01' AND t.date_new < '2016-06-01'
Group by
    transaction_month
Order by
    transaction_month;
    
#d) долю от общего количества операций за год и долю в месяц от общей суммы операций
With MonthlyData  AS (
   Select
       DATE_FORMAT(t.date_new, '%Y - %m') AS transaction_month,
       Count(t.Id_check) AS total_operations,
       SUM(t.Sum_payment) AS total_sum
	From
       transactions t 
	Where
       t.date_new>+ '2015-06-01' AND t.date_new < '2016-06-01'
	Group by
	   transaction_month
),
YearLyData AS (
    Select
        SUM(total_operations) AS yearly_operations,
		SUM(total_sum) AS yearly_sum
	From
        MonthlyData
)
Select
        md.transaction_month,
        md.total_operations,
        md.total_sum,
        md.total_operations/yd.yearly_operations * 100 AS
monthly_operations_share,
        md.total_sum/yd.yearly_sum * 100 AS monthly_sum_share
From
        MonthlyData md, YearlyData yd
Order by
        md.transaction_month;
        
   #e) вывести % соотношение M/F/NA в каждом месяце с их долей затрат
   
With MonthlyGenderStats AS (
   Select
      DATE_FORMAT(t.date_new, '%Y-%m') AS transaction_month,
      c.Gender,
      Sum(t.Sum_payment) AS total_amount,
      Count(*) AS total_operations
   From
      transactions t
   Join
      customers c ON t.ID_client = c.ID_client
   Where
      t.date_new>= '2015-06-01' AND t.date_new < '2016-06-01'
   Group by
	  transaction_month, c.Gender
),
TotalMonthlyStats As (
    Select
	  transaction_month,
      Sum(total_operations) AS total_operations,
      Sum(total_amount) AS total_amount
	From
      MonthlyGenderStats
	Group by
	  transaction_month
)
Select
    m.transaction_month,
    m.Gender,
    m.total_operations,
    m.total_amount,
    (m.total_operations/t.total_operations)* 100 AS operations_persectage,
    (m.total_amount/t.total_amount)* 100 AS amount_persentage
From
    MonthlyGenderStats m
Join
	TotalMonthlystats t ON m.transaction_month = t.transaction_month
Order by
    m.transaction_month, m.Gender;
     
#3 Возврастные группы клиентов с шагом 10 лет и отдельно клиентов,  у которых нет 
#данной информации, с параметрами сумма и коичество операций за весь период, и 
#поквартально - средние показатели и %

#Создание временной таблицы с возрастными группами и кварталами
Create TEMPORARY TABLE temp_age_data AS
   Select
       t.ID_client,
	   t.date_new,
       t.Sum_payment,
       t.Count_products,
       c.Age,
	   Case
		   When Age Is NULL THEN 'unknown'
		   When Age Between 0 AND 9 Then '0-9'
		   When Age Between 10 AND 19 Then '10-19'
		   When Age Between 20 AND 29 Then '20-29'
		   When Age Between 30 AND 39 Then '30-39'
		   When Age Between 40 AND 49 Then '40-49'
		   When Age Between 50 AND 59 Then '50-59'
		   When Age Between 60 AND 69 Then '60-69'
		   When Age Between 70 AND 79 Then '70-79'
		   Else '80+'
	   END AS age_group,
       CONCAT(YEAR(t.date_new), '-Q', QUARTER(t.date_new)) AS quarter
  From  transactions t
  LEFT JOIN customers c ON t.ID_client= c.Id_client;
          
# Общая статистика по возрастным группам (количество и сумма операций)
       
Create Temporary table temp_total_stats AS
Select
    age_group,
    Count(*) AS total_operations,
    SUM(Sum_payment) AS total_sum
From temp_age_data
Group by age_group;

#Средние показатели по кварталам
Create Temporary Table temp_avg_quarterly AS
Select
    age_group,
    AVG(operations_q) AS avg_operations_per_quarter,
    AVG(Sum_q) AS avg_sum_per_quarter
From (
    Select
         age_group,
         quarter,
         Count(*) AS operations_q,
         SUM(Sum_payment) AS sum_q
	From temp_age_data
    Group by age_group, quarter
)AS qdata
Group by age_group;
         
          
# Общее количество операций - для расчета процента
Select Count(*)Into @total_ops From temp_age_data;
          
# Финальный отчет по возрастным группам
Select 
    t.age_group,
    t.total_operations,
    t.total_sum,
    a.avg_operations_per_quarter,
    a.avg_sum_per_quarter,
    Round(100*t.total_operations/@total_ops, 2) AS persent_of_total_operations
From temp_total_stats t
Join temp_avg_quarterly a ON t.age_group
Order by
    Case
        When t.age_group = 'unknown' Then 99
        When t.age_group = '80+' Then 80
        Else Cast(Substring_index(t.age_group, '-', 1) AS UNSIGNED)
	END;
   
   