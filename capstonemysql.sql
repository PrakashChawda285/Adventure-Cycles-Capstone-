#Annual Revenue trends(year over year growth and peak performing years)
with yearly as  
            (select extract(year from OrderDate) as Year, sum(p.ProductPrice) as total_revenue
             from sales s join products p using (productkey)
			 group by Year),
growth as 
           (select  year , total_revenue , lag(total_revenue) over (order by year) as prev_year_sale
            from yearly),
yoy as 
           (select year , total_revenue,prev_year_sale, 
           round(((total_revenue - prev_year_sale)/prev_year_sale)*100 , 2) as "YOY_growth" from growth)
select year ,total_revenue,prev_year_sale, YOY_growth from yoy;


#Category Performance(product categories by total sales and margin across categories)
with category as 
            (select pc.ProductCategoryKey , pc.CategoryName , p.ProductCost,p.ProductPrice 
            from sales s join products p using (ProductKey)
			join product_subcategories ps using (productsubcategorykey)
            join product_categories pc using (productcategorykey)),
aggregation as     
           (select distinct Productcategorykey , categoryName , 
           round(sum(productprice - productcost) over(order by productcategorykey),2) as revenue_margin ,
		   round(sum(productprice) over(order by productcategorykey),2) as total_revenue from category) 
select CategoryName,total_revenue,revenue_margin,rank() over(order by total_revenue) as revenue_wise_rnk 
       from aggregation;



#Top & Underperforming products (by quantity and revenue generation)
with product_summary as 
			   (select p.ProductKey , p.ProductName , sum(s.OrderQuantity) as total_quantity,
               round(sum(productprice),2)as total_revenue
			   from sales s join products p using (productkey)
               group by p.ProductKey , p.ProductName),
 ranked as 
		      (select productkey , productname , total_quantity,total_revenue,
               rank() over(order by total_quantity desc) as best_qty,
               rank() over(order by total_quantity asc) as worst_qty,
               rank() over(order by total_revenue desc) as best_rev,
               rank() over(order by total_revenue asc) as worst_rev
               from product_summary)
select productkey ,productname , total_quantity , total_revenue 
from ranked where best_qty = 1 or  worst_qty = 1 or best_rev = 1 or  worst_rev = 1;



#Customer Segmentation by spend
with customer_spend as 
                  (select s.customerkey , p.ProductKey , p.ProductName , sum(p.ProductPrice) as total_spend
                   from sales s join products p using (productkey) 
				   group by s.customerkey , p.ProductKey , p.ProductName),
segmented as 
                 (select * , ntile(3) over (order by total_spend) as segment_group from customer_spend),
final as 
                (select  
                    case 
                          when segment_group = 1 then "Low"
                          when segment_group = 2 then "Mid"
					      else "High"
				   end as segment ,
                   round(sum(total_spend),2) as segmented_revenue
		       from segmented
               group by segment_group)
select segment , segmented_revenue , 
	  round(segmented_revenue * 100 / sum(segmented_revenue) over() , 2) as rev_share_percent
      from final 
      order by segmented_revenue desc;
      
 
 
 #Geographic Sales Leadership
SELECT 
    t.Country,
    t.Region,
    COUNT(DISTINCT s.OrderNumber) AS total_orders,
    SUM(s.OrderQuantity) AS total_quantity,
    ROUND(SUM(p.productprice * s.orderQuantity) / COUNT(DISTINCT s.ordernumber),
            2) AS avg_order_value,
    ROUND(SUM(p.ProductPrice), 2) AS total_sale
FROM
    sales s
        JOIN
    territories t ON s.TerritoryKey = t.SalesTerritoryKey
        JOIN
    products p ON p.ProductKey = s.ProductKey
GROUP BY t.Country , t.Region;



#Profitability by territory
with territory_profit as 
                   ( select  t.Region , t.Country ,  
                   round(sum(p.ProductCost * s.OrderQuantity),2) as total_cost,
                   round(sum(p.ProductPrice * s.OrderQuantity),2) as total_revenue,
                   round(sum((p.ProductPrice-p.ProductCost)* s.OrderQuantity),2) as profit,
                   round((sum((p.ProductPrice-p.ProductCost)* s.OrderQuantity) *100) /
                         (sum(p.ProductPrice * s.OrderQuantity)),2) as profit_margin_percent
				  from sales s 
                  join territories t on t.SalesTerritoryKey = s.TerritoryKey
                  join products p on p.ProductKey = s.ProductKey
                  group by t.Region , t.Country)
select * , rank() over (order by profit_margin_percent desc) as margin_rnk
from territory_profit;



#Return Analysis
with sales_data as 
              (select p.productkey , p.productname ,ps.Subcategoryname,pc.categoryname, 
			  sum(orderquantity) as sale_quantity
              from sales s 
              join products p using (productkey)
              join product_subcategories ps using (productsubcategorykey)
              join product_categories pc using (productcategorykey)
              group by productkey , productname , ps.Subcategoryname,pc.categoryname),
 return_data as 
             (select p.productkey ,p.productname , sum(returnquantity) as return_quantity
             from returns r join products p using (productkey)
             group by productkey , productname)
 select sd.productkey , sd.productname , sd.categoryname,sd.Subcategoryname,
 coalesce(rd.return_quantity , 0) as total_returned,
 round(coalesce(rd.return_quantity , 0)*100/(sale_quantity),2) as return_percent
 from sales_data sd 
 left join return_data rd on sd.productkey = rd.productkey;
 
 
 
 #Sales Seasonality(monthly and quarterly)
 with monthly_sales as 
                   (select date_format(orderdate , '%Y-%m') as month , 
				   round(sum(OrderQuantity*productprice),2) as total_revenue 
                   from sales s 
                   join products p using (productkey)
				   group by month),
 trend as 
                 (select month , total_revenue , 
                 lag(total_revenue) over (order by month) as prev_month,
                 lead(total_revenue) over(order by month) as next_month
                 from monthly_sales)
 select month , total_revenue,
       case 
       when total_revenue > prev_month and total_revenue > next_month then "peak"
       when total_revenue < prev_month and total_revenue < next_month then "Trough"
       else "Normal"
       end as trend_type
from trend;
SELECT 
    CONCAT(YEAR(orderdate),
            '-Q',
            QUARTER(orderdate)) AS Quarter,
    ROUND(SUM(OrderQuantity * productprice), 2) AS total_revenue
FROM
    sales s
        JOIN
    products p USING (productkey)
GROUP BY Quarter
ORDER BY Quarter;
 
 
#New Vs Returning Customers over time
with first_purchase as 
                (select s.CustomerKey,min(s.OrderDate) over() as first_order_date ,p.ProductPrice 
                from sales s 
                join products p using (productkey)),
classified as 
               (select f.* ,s.OrderDate,
                  case 
                       when s.OrderDate = f.first_order_date then "New"
                       else "Repeat"
                  end as customer_type
			   from sales s 
              join first_purchase f on s.customerkey = f.customerkey),
monthly_data as 
               (select date_format(orderdate , '%Y-%m') as month,
			    customer_type , round(sum(productprice),2) as total_revenue
               from classified
               group by month , customer_type)
select month , customer_type , total_revenue,
round((total_revenue * 100) / (sum(total_revenue) over (partition by month)),2) as revenue_share_percent
from monthly_data 
order by month, customer_type;
#PRAKASHCHAWDA

