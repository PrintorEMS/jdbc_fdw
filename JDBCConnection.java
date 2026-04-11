/*-------------------------------------------------------------------------
 *
 *                foreign-data wrapper for JDBC
 *
 * Portions Copyright (c) 2023, TOSHIBA CORPORATION
 *
 * This software is released under the PostgreSQL Licence
 *
 * IDENTIFICATION
 *                jdbc_fdw/JDBCConnection.java
 *
 *-------------------------------------------------------------------------
 */

import java.io.File;
import java.net.URL;
import java.sql.*;
import java.util.Properties;

public class JDBCConnection {
    private Connection conn = null;
    private boolean invalidate;
    private long server_hashvalue; // keep the uint32 val
    private long mapping_hashvalue; // keep the uint32 val

    private int queryTimeoutValue;
    private int fetchSizeValue;
    private static JDBCDriverLoader jdbcDriverLoader;

    public JDBCConnection(Connection conn, boolean invalidate, long server_hashvalue, long mapping_hashvalue, int queryTimeoutValue, int fetchSizeValue) {
        this.conn = conn;
        this.invalidate = invalidate;
        this.server_hashvalue = server_hashvalue;
        this.mapping_hashvalue = mapping_hashvalue;
        this.queryTimeoutValue = queryTimeoutValue;
        this.fetchSizeValue = fetchSizeValue;
    }

    public void close() throws SQLException {
        this.invalidate = true;
        if (this.conn != null) {
            this.conn.close();
            this.conn = null;
        }
    }

    /* get query timeout value */
    public int getQueryTimeout() {
        return queryTimeoutValue;
    }

    public int getFetchSize() {
        return fetchSizeValue;
    }

    public Connection getConnection() {
        return this.conn;
    }

    /* get jdbc connection, create new one if not cached before */
    public static JDBCConnection getConnection(int key, long server_hashvalue, long mapping_hashvalue, String[] options) throws Exception {
        return createConnection(key, server_hashvalue, mapping_hashvalue, options);
    }

    /* Make new connection */
    public static JDBCConnection createConnection(int key, long server_hashvalue, long mapping_hashvalue, String[] options) throws Exception {
        Properties jdbcProperties;
        Class<?> jdbcDriverClass = null;
        Driver jdbcDriver = null;
        String driverClassName = options[0];
        String url = options[1];
        String userName = options[2];
        String password = options[3];
        String qTimeoutValue = options[4];
        String fileName = options[5];
        String fetchSizeValue = options[6];

        try {
            File JarFile = new File(fileName);
            String jarfile_path = JarFile.toURI().toURL().toString();

            if (jdbcDriverLoader == null) {
                /* If jdbcDriverLoader is being created. */
                jdbcDriverLoader = new JDBCDriverLoader(new URL[] {JarFile.toURI().toURL()});
            } else if (jdbcDriverLoader.CheckIfClassIsLoaded(driverClassName) == null) {
                jdbcDriverLoader.addPath(jarfile_path);
            }

            /* Make connection */
            jdbcDriverClass = jdbcDriverLoader.loadClass(driverClassName);
            jdbcDriver = (Driver) jdbcDriverClass.newInstance();
            jdbcProperties = new Properties();
            jdbcProperties.put("user", userName);
            jdbcProperties.put("password", password);
            Connection conn = jdbcDriver.connect(url, jdbcProperties);

            if (conn == null)
                throw new SQLException("Cannot connect server: " + url);

            JDBCConnection Jconn = new JDBCConnection(conn, false, server_hashvalue, mapping_hashvalue, Integer.parseInt(qTimeoutValue), Integer.parseInt(fetchSizeValue));

            return Jconn;
        } catch (Throwable e) {
            throw e;
        }
    }
}
