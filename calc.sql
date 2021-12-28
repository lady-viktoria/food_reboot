use food_reboot;

-- рассчитать БЖУ пищи заданного пользователя по дням
select 
	m.user_id,
	DATE_FORMAT(m.meal_time, '%d.%m.%Y') as meals_date,	
	n.name,
	ROUND(sum(pn.value * m.value /100),1) as БЖУ_meal
from meals m 
	left join products p on p.id = m.product_id 
	left join product_nutrients pn on pn.product_id = p.id
	left join nutrients n on n.id = pn.nutrient_id 
	left join users u on u.id =m.user_id 
	where m.user_id =5
	group by DAYOFYEAR(m.meal_time), n.id;

-- расчет сумм нутриентов в разрезе рецептов (на весь рецепт)
select r.name as r_name, ntr.name as ntr_name, sum(ri.value/100*pn.value) as val from recipe r
left join recipe_item ri on ri.recipe_id = r.id 
left join product_nutrients pn on pn.product_id = ri.product_id
left join products pr on pr.id = pn.product_id
left join nutrients ntr on ntr.id = pn.nutrient_id 
-- where r.id = 1
group by r.id, ntr.id

-- рассчитать сумму масс ингридиентов рецепта
select r.name, sum(ri.value) from recipe_item ri 
left join recipe r on ri.recipe_id = r.id
group by r.id

-- расчет БЖУ на 100 гр рецепта
select 
	r.name as r_name, 
	ntr.name as ntr_name, 
	sum(ri.value/100*pn.value)/r_sums.sm*100 as val_in_100gr 
from recipe r
left join (
	select recipe_s.id, recipe_s.name, sum(recipe_item_s.value) as sm 
	from recipe_item recipe_item_s
	left join recipe recipe_s on recipe_item_s.recipe_id = recipe_s.id
	group by recipe_s.id
) r_sums on r_sums.id = r.id 
left join recipe_item ri on ri.recipe_id = r.id 
left join product_nutrients pn on pn.product_id = ri.product_id
left join products pr on pr.id = pn.product_id
left join nutrients ntr on ntr.id = pn.nutrient_id 
-- where r.id = 1
group by r.id, ntr.id

-- найти продукт/рецепт с максимальной калорийностью на 100 гр
select 
	p.name,
	round(pn.value,1) as ccal
from products p
left join product_nutrients pn on pn.product_id = p.id 
where pn.nutrient_id = 4
order by pn.value desc;

-- найти продукты/рецепты, удовлетворяющие следующим условиям: 
-- белки > 20г и жиры < 20г и углеводы < 50г на 100г

select 
	p.name,
	fats.value as fats_gr,
	proteins.value as proteins_gr,
	carbs.value as carbs_gr
from products p 
left join product_nutrients fats on fats.product_id = p.id
left join product_nutrients proteins on proteins.product_id = p.id
left join product_nutrients carbs on carbs.product_id = p.id
where 
	(fats.nutrient_id = 1 and fats.value < 20) and 
	(proteins.nutrient_id = 2 and proteins.value > 20) and 
	(carbs.nutrient_id = 3 and carbs.value < 50);

-- продукты, которые кушал данный пользователь (для составления списка продуктов)
-- сортировка по количеству раз употребления одного продукта позволит определить любимые продукты))
select 
	u2.id,
	u2.firstname as user_name, 
	p2.id as id_product,
	p2.name,
	count(p2.id) as cnt
from meals m 
left join products p2 on p2.id = m.product_id 
left join users u2 on u2.id = m.user_id 
group by u2.id, p2.id 
order by u2.id, cnt 
;

-- представление
drop view if exists calc_on_day;
create view calc_on_day as select  
	m.user_id,
	DATE_FORMAT(m.meal_time, '%d.%m.%Y') as meals_date,	
	n.name,
	ROUND(sum(pn.value * m.value /100),1) as БЖУ_meal
from meals m 
	left join products p on p.id = m.product_id 
	left join product_nutrients pn on pn.product_id = p.id
	left join nutrients n on n.id = pn.nutrient_id 
	left join users u on u.id =m.user_id 
	group by m.user_id, DAYOFYEAR(m.meal_time), n.id
	order by m.user_id, DAYOFYEAR(m.meal_time);














