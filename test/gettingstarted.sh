gmkuser -n "Wilkes, Amy" -E "amy@western.edu" amy
gmkuser -n "Smith, Robert F." -E "bob@western.edu" bob
gmkuser -n "Miller, David" -E "dave@western.edu" dave
glsuser

gmkmachine -d "SGI Altix" altix
gmkmachine -d "IBM SP2" blue
gmkmachine -d "Linux Cluster" colony
glsmachine

gmkproject -d "Biology Department" biology
gchproject --addUsers amy,bob biology

gmkproject -d "Chemistry Department" chemistry --createAccount=False
gchproject --addUsers amy,bob,dave chemistry
gmkaccount -p chemistry -u MEMBERS -m colony -n "chemistry on colony"
gmkaccount -p chemistry -u amy -n "chemistry for amy"
gmkaccount -p chemistry -u MEMBERS,-amy -n "chemistry not amy"

glsproject
glsaccount

gdeposit -s 2012-01-01 -e 2012-04-01 -z 25000000 -p biology
gdeposit -s 2012-04-01 -e 2012-07-01 -z 25000000 -p biology
gdeposit -s 2012-07-01 -e 2012-10-01 -z 25000000 -p biology
gdeposit -s 2012-10-01 -e 2013-01-01 -z 25000000 -p biology

gdeposit -s 2012-01-01 -e 2013-01-01 -z 50000000 -a 2
gdeposit -s 2012-01-01 -e 2013-01-01 -z 9000000 -L 1000000 -a 3
gdeposit -s 2012-01-01 -e 2013-01-01 -z 40000000 -a 4

glsaccount
glsalloc

gbalance -u amy
gbalance -u amy -p chemistry -m colony
gbalance -u amy -p chemistry -m colony --total
gbalance -u amy -p chemistry -m colony --total --available --quiet

gquote -p chemistry -u amy -m colony -P 16 -t 3600 --guarantee

greserve -J PBS.1234.0 -p chemistry -u amy -m colony -P 16 -t 3600 -q 1

gbalance -u amy -p chemistry -m colony --total
gbalance -u amy -p chemistry -m colony
glsres

glsaccount -u amy
glsalloc -A -a 3

gcharge -J PBS.1234.0 -u amy -p chemistry -m colony -P 16 -t 1234 -q 1

gbalance -u amy -p chemistry -m colony
gbalance -u amy -p chemistry -m colony --total
glsjob

grefund -J PBS.1234.0

gbalance -u amy -p chemistry -m colony
glsjob

glstxn -O Job --show="RequestId,TransactionId,Object,Action,JobId,Project,User,Machine,Amount"
glstxn -R 327 --show="Id,Object,Action,Name,JobId,Amount,Account,Delta"

gstatement -a 3

gusage chemistry
