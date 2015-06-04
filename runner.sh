cp db-example.txt db1.txt
screen -dm ./ims -d db1.txt -p 15400 -i 3 -v 1
cp db-example.txt db2.txt
screen -dm ./rims -d db2.txt -p 15401 -i 3 -v 1
read -p ""
killall -15 screen
