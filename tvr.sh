#!/usr/bin/env bash
# TVR - FRR 5-node ring topology 관리 스크립트
set -euo pipefail

cd "$(dirname "$0")"

COMPOSE="docker compose"
NODES=(r1 r2 r3 r4 r5)

usage() {
  cat <<USAGE
사용법: ./tvr.sh <command> [args]

  up                  컨테이너 전체 기동 (detached)
  down                컨테이너 전체 종료 및 네트워크 삭제
  restart [node]      전체 또는 특정 노드 재시작
  status              컨테이너 상태 확인
  logs [node]         로그 출력 (follow)
  sh <node>           해당 노드 vtysh 접속 (예: ./tvr.sh sh r1)
  exec <node> <cmd>   해당 노드에서 vtysh 명령 실행 (예: ./tvr.sh exec r1 "show ip route")
  ospf                모든 노드의 OSPF neighbor 상태 출력
  routes              모든 노드의 라우팅 테이블 출력
  ping                r1 에서 각 노드 루프백(10.255.0.N)으로 ping 테스트
  help                이 도움말
USAGE
}

require_node() {
  local n="${1:-}"
  if [[ -z "$n" ]]; then
    echo "노드 이름이 필요합니다. (${NODES[*]})" >&2
    exit 1
  fi
  if [[ ! " ${NODES[*]} " =~ " $n " ]]; then
    echo "알 수 없는 노드: $n (${NODES[*]})" >&2
    exit 1
  fi
}

cmd="${1:-help}"
shift || true

case "$cmd" in
  up)
    $COMPOSE up -d "$@"
    $COMPOSE ps
    ;;
  down)
    $COMPOSE down "$@"
    ;;
  restart)
    if [[ $# -gt 0 ]]; then
      require_node "$1"
      $COMPOSE restart "$1"
    else
      $COMPOSE restart
    fi
    ;;
  status|ps)
    $COMPOSE ps
    ;;
  logs)
    if [[ $# -gt 0 ]]; then
      require_node "$1"
    fi
    $COMPOSE logs -f "$@"
    ;;
  sh|vtysh)
    require_node "${1:-}"
    docker exec -it "$1" vtysh
    ;;
  exec)
    require_node "${1:-}"
    node="$1"; shift
    if [[ $# -eq 0 ]]; then
      echo "실행할 vtysh 명령이 필요합니다." >&2
      exit 1
    fi
    docker exec "$node" vtysh -c "$*"
    ;;
  ospf)
    for n in "${NODES[@]}"; do
      echo "===== $n ====="
      docker exec "$n" vtysh -c "show ip ospf neighbor"
    done
    ;;
  routes)
    for n in "${NODES[@]}"; do
      echo "===== $n ====="
      docker exec "$n" vtysh -c "show ip route"
    done
    ;;
  ping)
    for i in 1 2 3 4 5; do
      printf "r1 -> 10.255.0.%s : " "$i"
      if docker exec r1 ping -c 1 -W 1 "10.255.0.$i" >/dev/null 2>&1; then
        echo "OK"
      else
        echo "FAIL"
      fi
    done
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    echo "알 수 없는 명령: $cmd" >&2
    usage
    exit 1
    ;;
esac
