find -regex ".*-.*.sh" | sort | xargs -n1 bash | tee $1 | grep "P5IMS TEST "
