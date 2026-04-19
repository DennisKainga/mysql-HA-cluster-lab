.PHONY: help up down seed status clean-all

help:
	@echo "  make up 	- Start Cluster Monitoring"
	@echo "  make status    		- Check health of all systems"
	@echo "  make down      		- Stop everything"


up:
	@echo "Starting Monitoring..."
	docker compose up -d
	
status:
	@docker compose ps

down:
	@echo "Stopping Monitoring..."
	docker compose down -v