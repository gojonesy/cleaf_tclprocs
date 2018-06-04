#!/usr/bin/env tcl
# SQLite Stuff
# 03/29/2017 - Jones - Created

global HciRoot; set debug 0

sqlite3 testdb $HciRoot/sqlite_tables/test.db

testdb eval {CREATE TABLE test(id int, name text)}
testdb eval {INSERT INTO test VALUES(1, 'Justin')}
testdb eval {INSERT INTO test VALUES(2, 'Mitzi')}
testdb eval {INSERT INTO test VALUES(3, 'Dan')}
testdb eval {INSERT INTO test VALUES(4, 'Mike')}
testdb eval {INSERT INTO test VALUES(5, 'Michelle')}

testdb eval {SELECT * FROM test ORDER BY name} values {
	parray values
	puts ""
}

testdb close