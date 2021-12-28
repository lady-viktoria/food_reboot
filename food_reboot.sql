/*
База данных Food_reboot позволяет решать следующие задачи:
1. хранение продуктов и значения их нутриентов (жиры, белки, углеводы, калорийность)
2. создавать и рассчитывать БЖУ рецептов.
Структура БД Food_reboot реализована таким образом, что внесенные пользователем рецепты 
рассчитываются по нутриентам и добавляются в список продуктов. Помимо прочего это позволяет 
использовать этот продукт в качестве ингридиента в другом рецепте.
3. позволяет вести учет приемов пищи, в том числе в разрезе дней, нутриентов.

Рецепт пересчитывается при изменении любого из его составляющих. 
Различные варианты выборок и группировок дают возможность гибкого анализа питания. Например, можно определить:
- БЖУ пищи заданного пользователя по дням
- найти продукт/рецепт с максимальной калорийностью на 100 гр
- определить любимые продукты и другое.
*/


drop database if exists food_reboot;
create database food_reboot;

use food_reboot;

DROP TABLE IF EXISTS users;
CREATE TABLE users (
	id SERIAL PRIMARY KEY, -- SERIAL = BIGINT UNSIGNED NOT NULL AUTO_INCREMENT UNIQUE
	firstname VARCHAR(100),
	lastname VARCHAR(100) COMMENT 'Фамилия',
	email VARCHAR(100) UNIQUE,
    password_hash varchar(100),
    phone BIGINT UNSIGNED,
    INDEX users_firstname_lastname_idx(firstname, lastname)
);

drop table if exists `profiles`;
create table `profiles` (
	user_id SERIAL primary key,
	gender CHAR(1),
	birthday DATE,
	weight int,
	height int,
	photo_id BIGINT UNSIGNED NULL,
	created_at DATETIME default NOW(),
	
	FOREIGN KEY (user_id) REFERENCES users(id) ON UPDATE CASCADE ON DELETE CASCADE
);

drop table if exists `recipe`;
create table `recipe` (
	id SERIAL PRIMARY KEY,
	user_id BIGINT UNSIGNED,
	name VARCHAR(255),
	description VARCHAR(255),
	
	FOREIGN KEY (user_id) REFERENCES users(id) ON UPDATE CASCADE ON DELETE CASCADE
);

drop table if exists `products`;
create table `products` (
	id SERIAL PRIMARY KEY,
	recipe_id BIGINT UNSIGNED,
	name VARCHAR(255),
	FOREIGN KEY (recipe_id) REFERENCES recipe(id) ON UPDATE CASCADE ON DELETE CASCADE
);

drop table if exists `nutrients`;
create table `nutrients` (
	id SERIAL PRIMARY KEY,
	name VARCHAR(255)	
);

drop table if exists `units`;
create table `units` (
	id SERIAL PRIMARY KEY,
	name VARCHAR(255)	
);

DROP TABLE IF EXISTS product_nutrients;
CREATE TABLE product_nutrients(
	id SERIAL PRIMARY KEY,
	unit_id BIGINT UNSIGNED NOT NULL,
    product_id BIGINT UNSIGNED NOT NULL,
    nutrient_id BIGINT UNSIGNED NOT NULL,
    value float(2),
    
  	FOREIGN KEY (nutrient_id) REFERENCES nutrients(id) ON UPDATE CASCADE ON DELETE CASCADE,
  	FOREIGN KEY (unit_id) REFERENCES units(id) ON UPDATE CASCADE ON DELETE CASCADE,
  	FOREIGN KEY (product_id) REFERENCES products(id) ON UPDATE CASCADE ON DELETE CASCADE
);



drop table if exists `recipe_item`;
create table `recipe_item` (
	id SERIAL PRIMARY KEY,
	recipe_id BIGINT UNSIGNED NOT NULL,
	product_id BIGINT UNSIGNED NOT NULL,
	value int,
	unit_id BIGINT UNSIGNED NOT NULL,
	
	FOREIGN KEY (recipe_id) REFERENCES recipe(id) ON UPDATE CASCADE ON DELETE CASCADE,
	FOREIGN KEY (product_id) REFERENCES products(id) ON UPDATE CASCADE ON DELETE CASCADE,
	FOREIGN KEY (unit_id) REFERENCES units(id) ON UPDATE CASCADE ON DELETE CASCADE
);

drop table if exists `meals`;
create table `meals` (
	id SERIAL PRIMARY KEY,
	user_id BIGINT UNSIGNED,
	product_id BIGINT UNSIGNED,
	value int,
	unit_id BIGINT UNSIGNED NOT NULL,
	meal_time DATETIME DEFAULT NOW(),
	
	FOREIGN KEY (user_id) REFERENCES users(id) ON UPDATE CASCADE ON DELETE CASCADE,
	-- FOREIGN KEY (recipe_id) REFERENCES recipe(id) ON UPDATE CASCADE ON DELETE CASCADE,
	FOREIGN KEY (product_id) REFERENCES products(id) ON UPDATE CASCADE ON DELETE CASCADE,
	FOREIGN KEY (unit_id) REFERENCES units(id) ON UPDATE CASCADE ON DELETE CASCADE
);


-- создание процедуры по добавлению/пересчету рецепта в продукты
-- составные части процедуры представлены в файле calc.sql 

DROP PROCEDURE IF EXISTS product_from_recipe;

delimiter //


CREATE PROCEDURE product_from_recipe(IN for_recipe_id BIGINT)
BEGIN
	-- удаление нутриентов продуктов, входящих в состав нашего рецепта
	delete from product_nutrients 
	where product_nutrients.product_id in (
		select id from products where products.recipe_id = for_recipe_id
	);
	
	-- если продукт на базе рецепта существует 
    IF((select count(*) from products where products.recipe_id = for_recipe_id) > 0) then
    	-- обновим
    	UPDATE products
		SET name=(select name from recipe where recipe.id = for_recipe_id)
		WHERE products.recipe_id = for_recipe_id;
    else
    	-- добавление рецепта в таблицу продуктов
		INSERT INTO products (recipe_id, name)
		select id, name from recipe where recipe.id = for_recipe_id;
    end if;
   
    -- добавляем пересчитанные нутриенты продукта на базе рецепта, если есть составляющие рецепта
    if ((select count(*) from recipe_item where recipe_item.recipe_id = for_recipe_id) > 0) then
	    insert into product_nutrients (unit_id, product_id, nutrient_id, value)
	    (
	    -- расчет БЖУ на 100 гр рецепта
			select
			    pn.unit_id,
			    prrec.id,
				ntr.id,
				sum(ri.value/100*pn.value)/r_sums.sm*100 as val_in_100gr 
			from recipe r
			left join (
			-- рассчитать сумму масс ингридиентов рецепта
				select recipe_s.id, recipe_s.name, sum(recipe_item_s.value) as sm 
				from recipe_item recipe_item_s
				left join recipe recipe_s on recipe_item_s.recipe_id = recipe_s.id
				group by recipe_s.id
			) r_sums on r_sums.id = r.id
			-- продукт в который будем сводить бжу рецепта
			left join products prrec on prrec.recipe_id = for_recipe_id
			left join recipe_item ri on ri.recipe_id = r.id 
			left join product_nutrients pn on pn.product_id = ri.product_id
			left join products pr on pr.id = pn.product_id
			left join nutrients ntr on ntr.id = pn.nutrient_id 
			where r.id = for_recipe_id
			group by ntr.id
	    );
   end if;
	
END//

delimiter ;

-- CALL product_from_recipe(1);


-- триггер на изменение записи в recipe.
DROP TRIGGER IF EXISTS auto_update_product_on_recipe_update;
DELIMITER //

CREATE TRIGGER auto_update_product_on_recipe_update AFTER update ON recipe 
FOR EACH ROW
begin
	CALL product_from_recipe(new.id); 
END//

-- триггер на изменение записи в recipe_item.
DROP TRIGGER IF EXISTS auto_update_product_on_recipe_item_update;
DELIMITER //

CREATE TRIGGER auto_update_product_on_recipe_item_update AFTER update ON recipe_item 
FOR EACH ROW
begin
	CALL product_from_recipe(new.recipe_id); 
END//

-- триггер на добавление записи в recipe_item.
DROP TRIGGER IF EXISTS auto_update_product_on_recipe_item_insert;
DELIMITER //

CREATE TRIGGER auto_update_product_on_recipe_item_insert AFTER insert ON recipe_item 
FOR EACH ROW
begin
	CALL product_from_recipe(new.recipe_id); 
END//

-- триггер на удаление записи в recipe_item.
DROP TRIGGER IF EXISTS auto_update_product_on_recipe_item_delete;
DELIMITER //

CREATE TRIGGER auto_update_product_on_recipe_item_delete AFTER delete ON recipe_item 
FOR EACH ROW
begin
	CALL product_from_recipe(old.recipe_id); 
END//













