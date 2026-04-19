.PHONY: help up cluster-up monitoring-up down seed status clean-all

help:
	@echo "Sophionic Lab Root Control"
	@echo "  up 					- Start Cluster, Then monitoring"
	@echo "  make cluster-up 		- Start Cluster"
	@echo "  make monitoring-up 	- Start Cluster Monitoring"
	@echo "  make seed      		- Run the seeding script"
	@echo "  make status    		- Check health of all systems"
	@echo "  make down      		- Stop everything"


up:
	@echo "Starting HA Core Stack..."
	docker compose up -d
	@echo "Starting Monitoring..."
	$(MAKE) -C monitoring up

cluster-up:
	@echo "Starting MySQL InnoDB Cluster..."
	docker compose up -d

monitoring-up:
	@echo "Starting Monitoring..."
	$(MAKE) -C monitoring up
	
seed:
	@echo "Executing Seed Scripts..."
	$(MAKE) -C seeding seed

status:
	@echo "--- Cluster Status ---"
	@docker compose ps
	@echo "\n--- Monitoring Status ---"
	@$(MAKE) -C monitoring status || echo "Monitoring not running."

down:
	@echo "Stopping Monitoring..."
	@$(MAKE) -C monitoring down || true
	@echo "Stopping Cluster..."
	docker compose down -v