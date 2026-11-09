WITH account_metrics AS ( 
SELECT
COUNT(DISTINCT a.id) AS account_cnt,
s.date,
sp.country,
a.send_interval,
a.is_verified,
a.is_unsubscribed,
NULL AS email_sent,
NULL AS email_open,
NULL AS email_visit
FROM data-analytics-mate.DA.account AS a
JOIN data-analytics-mate.DA.account_session AS acs
ON a.id = acs.account_id
JOIN data-analytics-mate.DA.session_params AS sp
ON acs.ga_session_id = sp.ga_session_id
JOIN data-analytics-mate.DA.session AS s
ON acs.ga_session_id = s.ga_session_id
GROUP BY
s.date,
sp.country,
a.send_interval,
a.is_verified,
a.is_unsubscribed
),

email_metrics AS(
 SELECT
 NULL AS account_cnt,
 DATE_ADD(s.date,INTERVAL es.sent_date DAY) AS sent_date,
 sp.country,
 a.send_interval,
 a.is_verified,
 a.is_unsubscribed,
 COUNT(DISTINCT es.id_message) AS email_sent,
 COUNT(DISTINCT eo.id_message) AS email_open,
 COUNT(DISTINCT ev.id_message) AS email_visit
 FROM data-analytics-mate.DA.email_sent AS es
 LEFT JOIN data-analytics-mate.DA.email_open AS eo
 ON es.id_message = eo.id_message
 LEFT JOIN data-analytics-mate.DA.email_visit AS ev
 ON es.id_message = ev.id_message
 LEFT JOIN data-analytics-mate.DA.account_session AS acs
 ON es.id_account = acs.account_id
 JOIN data-analytics-mate.DA.account AS a
 ON a.id = acs.account_id
 JOIN data-analytics-mate.DA.session_params AS sp
 ON acs.ga_session_id = sp.ga_session_id
 JOIN data-analytics-mate.DA.session AS s
 ON acs.ga_session_id = s.ga_session_id
 GROUP BY
 sent_date,
 sp.country,
 a.send_interval,
 a.is_verified,
 a.is_unsubscribed
),

union_metrics AS (
SELECT *
FROM account_metrics


UNION ALL


SELECT *
FROM email_metrics
),

message_cnt AS (
SELECT
date,
country,
send_interval,
is_verified,
is_unsubscribed,
SUM(COALESCE(account_cnt, 0)) AS account_cnt,
SUM(COALESCE(email_sent, 0)) AS sent_msg,
SUM(COALESCE(email_open, 0)) AS open_msg,
SUM(COALESCE(email_visit, 0)) AS visit_msg
FROM union_metrics
GROUP BY
date,
country,
send_interval,
is_verified,
is_unsubscribed
ORDER BY
date,
country,
send_interval
),


final AS(
SELECT
*,
SUM(account_cnt) OVER(PARTITION BY country) AS total_country_account_cnt,
SUM(sent_msg) OVER(PARTITION BY country) AS total_country_sent_cnt
FROM message_cnt
),


ranking AS (
SELECT
*,
DENSE_RANK() OVER(ORDER BY total_country_account_cnt DESC) AS rank_total_country_account_cnt,
DENSE_RANK() OVER(ORDER BY total_country_sent_cnt DESC) AS rank_total_country_sent_cnt
FROM final
)


SELECT *
FROM ranking
WHERE rank_total_country_account_cnt <= 10 OR rank_total_country_sent_cnt <= 10
ORDER BY
rank_total_country_account_cnt,
rank_total_country_sent_cnt;
