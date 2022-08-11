#! /bin/bash

function usage() {
    cat <<USAGE

    Usage: $0 [-n namespace] [--get-logs]

    Options:
        -n, --namespace:	set a namespace to execute Script
	      --get-logs:		to get logs from pods in CrashLoopBackOff status
USAGE
    exit 1
}

if [ $# -eq 0 ]; then
    echo -ne "You must provide one of these namespaces >>\n$(kubectl get ns -o jsonpath='{.items[*].metadata.name}'| xargs -n1)";
    exit 1
fi

NAMESPACE=
LOGS=false
LOGDIR="podslogs"

while [ "$1" != "" ]; do
    case $1 in
    -n | --namespace)
        shift
        NAMESPACE=$1
        ;;
    --get-logs)
        LOGS=true
	if ! [[ -d ${LOGDIR} ]]; then
	  mkdir ${LOGDIR}
	fi
	;;
    -h | --help)
        usage
        ;;
    *)
        echo -ne "You must provide one of these namespaces >>\n$(kubectl get ns -o jsonpath='{.items[*].metadata.name}'| xargs -n1)";
        exit 1
        ;;
    esac
    shift
done

crash_pods_list=$(kubectl -n ${NAMESPACE} get po -o jsonpath='{.items[*].status.containerStatuses[?(@.state.waiting.reason=="CrashLoopBackOff")].name}'| xargs -n1 | uniq)
COUNTER=0
FILE_REPORT='report_deployments.log'
echo "The following deployments have been changed to replicas 0, due to CrashLoopBackOff status: " > $FILE_REPORT
  
if [[ ${LOGS} == false ]]; then
  for pod in ${crash_pods_list[@]}; do
    kubectl -n ${NAMESPACE} scale deployment/${pod} --replicas==0
    if [[ $? == 0 ]]; then
      echo -ne "${pod}\n" >> $FILE_REPORT 
      ((COUNTER++))
    fi
  done
else
  for pod in ${crash_pods_list[@]}; do
    kubectl logs -l app=${pod} > ${LOGDIR}/${pod}.log
    kubectl -n ${NAMESPACE} scale deployment/${pod} --replicas==0
    if [[ $? == 0 ]]; then
      echo -ne "${pod}\n" >> $FILE_REPORT 
      ((COUNTER++))
    fi
  done
fi


if [[ ${COUNTER} == 0 ]]; then
  rm -f ${FILE_REPORT}
fi
