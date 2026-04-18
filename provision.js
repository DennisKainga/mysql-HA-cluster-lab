try {
    var session = shell.connect('root@db1:3306', 'password');
    
    var cluster;
    try {
        cluster = dba.getCluster('SophionicCluster');
    } catch (e) {

    }
    
    if (cluster) {
        print("\n--- Sophionic Cluster is ONLINE ---\n");
    } else {
        print("\n--- Initializing New Sophionic Cluster ---\n");
        // Ensure the root user has the right permissions before clustering
        session.runSql("CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY 'password';");
        session.runSql("GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;");
        
        dba.configureInstance('root@db1:3306', {password: 'password', interactive: false, clearReadOnly: true});
        dba.configureInstance('root@db2:3306', {password: 'password', interactive: false, clearReadOnly: true});
        dba.configureInstance('root@db3:3306', {password: 'password', interactive: false, clearReadOnly: true});

        cluster = dba.createCluster('SophionicCluster');
        cluster.addInstance('root@db2:3306', {password: 'password', recoveryMethod: 'clone'});
        cluster.addInstance('root@db3:3306', {password: 'password', recoveryMethod: 'clone'});
    }

    print(cluster.status());

} catch (e) {
    if (e.message.includes("already belongs to an InnoDB cluster")) {
        print("\n--- Sophionic Cluster detected. ---\n");
    } else {
        print("Unexpected error: " + e.message);
        // Use 'exit' for MySQL Shell
        // return; 
        shell.exit(1);
    }
}