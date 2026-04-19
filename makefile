DB_CONTAINER=mysql-router
DB_USER=root
DB_PASS=password
SQL_FILE=./seeding/data.sql

.PHONY: help seed clean status

help:
	@echo "Sophionic Cluster Lab - Library Demo"
	@echo "  make seed   - Create Authors/Books/Comments and insert data"
	@echo "  make clean  - Drop the library_lab database"
	@echo "  make status - Verify cluster nodes are ONLINE"

seed:
	@echo "Deploying Library Schema to Cluster via Router..."
	@docker exec -i $(DB_CONTAINER) mysql -h 127.0.0.1 -P 6446 -u$(DB_USER) -p$(DB_PASS) < $(SQL_FILE)
	@echo "Success! Database 'library_lab' is populated."

clean:
	@echo "Cleaning up demo data..."
	@docker exec -i $(DB_CONTAINER) mysql -h 127.0.0.1 -P 6446 -u$(DB_USER) -p$(DB_PASS) -e "DROP DATABASE IF EXISTS library_lab;"

status:
	@docker exec -it cluster-setup mysqlsh --uri $(DB_USER):$(DB_PASS)@db1:3306 --js -e "print(dba.getCluster('SophionicCluster').status())"