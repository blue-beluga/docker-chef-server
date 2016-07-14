#!/usr/bin/env bats

setup() {
  docker history "$REGISTRY/$REPOSITORY:$TAG" >/dev/null 2>&1
  export IMG="$REGISTRY/$REPOSITORY:$TAG"
}

@test "that the root password is disabled" {
  run docker run --user nobody $IMG su
  [ $status -eq 1 ]
}
