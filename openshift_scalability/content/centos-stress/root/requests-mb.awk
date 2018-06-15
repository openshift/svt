/server-http-/ { # insecure routes
  if (i) {printf "\n  },\n" }
  printf "  {\n"
#  printf "    \"host_from": \"192.168.0.102\",
  printf "    \"scheme\": \"http\",\n"
#  printf "    \"tls-session-reuse\": %s,\n", tls_session_reuse
  printf "    \"host\": \"%s\",\n", $1
  printf "    \"port\": 80,\n"
  printf "    \"method\": \"GET\",\n"
  printf "    \"path\": \"%s\",\n", path
#  printf "    \"headers\": {\n"
#  printf "      \"Content-Type\": \"application/x-www-form-urlencoded\",\n"
#  printf "      \"X-Custom-Header-2\": \"test 2\"\n"
#  printf "    },\n"
#  printf "    \"body\": \"name=user&email=user@example.com\",\n"
  printf "    \"keep-alive-requests\": %s,\n", ka_requests
  printf "    \"clients\": %s,\n", clients
  printf "    \"delay\": {\n"
  printf "      \"min\": %s,\n", delay_min
  printf "      \"max\": %s\n", delay_max
  printf "    }"
  i++
}
/server-tls-/ { # secure routes
  if (i) {printf "\n  },\n" }
  printf "  {\n"
  printf "    \"scheme\": \"https\",\n"
  printf "    \"tls-session-reuse\": %s,\n", tls_session_reuse
  printf "    \"host\": \"%s\",\n", $1
  printf "    \"port\": 443,\n"
  printf "    \"method\": \"GET\",\n"
  printf "    \"path\": \"%s\",\n", path
  printf "    \"keep-alive-requests\": %s,\n", ka_requests
  printf "    \"clients\": %s,\n", clients
  printf "    \"delay\": {\n"
  printf "      \"min\": %s,\n", delay_min
  printf "      \"max\": %s\n", delay_max
  printf "    }"
  i++
}
/^cakephp-/ {
  if (i) {printf "\n  },\n" }
  printf "  {\n"
  printf "    \"scheme\": \"http\",\n"
  printf "    \"host\": \"%s\",\n", $1
  printf "    \"port\": 80,\n"
  printf "    \"method\": \"GET\",\n"
  printf "    \"path\": \"%s\",\n", path
  printf "    \"keep-alive-requests\": %s,\n", ka_requests
  printf "    \"clients\": %s,\n", clients
  printf "    \"delay\": {\n"
  printf "      \"min\": %s,\n", delay_min
  printf "      \"max\": %s\n", delay_max
  printf "    }"
  i++
}
/^dancer-/ {
  if (i) {printf "\n  },\n" }
  printf "  {\n"
  printf "    \"scheme\": \"http\",\n"
  printf "    \"host\": \"%s\",\n", $1
  printf "    \"port\": 80,\n"
  printf "    \"method\": \"POST\",\n"
  printf "    \"path\": \"%s\",\n", path
  printf "    \"headers\": {\n"
  printf "      \"Content-Type\": \"application/x-www-form-urlencoded\"\n"
  printf "    },\n"
  printf "    \"body\": \"name=user&email=user@example.com\",\n"
  printf "    \"keep-alive-requests\": %s,\n", ka_requests
  printf "    \"clients\": %s,\n", clients
  printf "    \"delay\": {\n"
  printf "      \"min\": %s,\n", delay_min
  printf "      \"max\": %s\n", delay_max
  printf "    }"
  i++
}
/^django-/ {
  if (i) {printf "\n  },\n" }
  printf "  {\n"
  printf "    \"scheme\": \"http\",\n"
  printf "    \"host\": \"%s\",\n", $1
  printf "    \"port\": 80,\n"
  printf "    \"method\": \"GET\",\n"
  printf "    \"path\": \"/\",\n"
  printf "    \"keep-alive-requests\": 100,\n"
  printf "    \"clients\": 10,\n"
  printf "    \"delay\": {\n"
  printf "      \"min\": %s,\n", delay_min
  printf "      \"max\": %s\n", delay_max
  printf "    }"
  i++
}
/^eap-/ {
  if (i) {printf "\n  },\n" }
  printf "  {\n"
  printf "    \"scheme\": \"http\",\n"
  printf "    \"host\": \"%s\",\n", $1
  printf "    \"port\": 80,\n"
  printf "    \"method\": \"POST\",\n"
  printf "    \"path\": \"%s\",\n", path
  printf "    \"headers\": {\n"
  printf "      \"Content-Type\": \"application/x-www-form-urlencoded\"\n"
  printf "    },\n"
  printf "    \"body\": \"summary=eap:+get+stuff+done&description=eap:+omg+so+many+things\",\n"
  printf "    \"keep-alive-requests\": %s,\n", ka_requests
  printf "    \"clients\": %s,\n", clients
  printf "    \"delay\": {\n"
  printf "      \"min\": %s,\n", delay_min
  printf "      \"max\": %s\n", delay_max
  printf "    }"
  i++
}
/^nodejs-/ {
  if (i) {printf "\n  },\n" }
  printf "  {\n"
  printf "    \"scheme\": \"http\",\n"
  printf "    \"host\": \"%s\",\n", $1
  printf "    \"port\": 80,\n"
  printf "    \"method\": \"GET\",\n"
  printf "    \"path\": \"%s\",\n", path
  printf "    \"keep-alive-requests\": %s,\n", ka_requests
  printf "    \"clients\": %s,\n", clients
  printf "    \"delay\": {\n"
  printf "      \"min\": %s,\n", delay_min
  printf "      \"max\": %s\n", delay_max
  printf "    }"
  i++
}
/^rails-/ {
  if (i) {printf "\n  },\n" }
  printf "  {\n"
  printf "    \"scheme\": \"http\",\n"
  printf "    \"host\": \"%s\",\n", $1
  printf "    \"port\": 80,\n"
  printf "    \"method\": \"GET\",\n"
  printf "    \"path\": \"%s\",\n", path
  printf "    \"keep-alive-requests\": %s,\n", ka_requests
  printf "    \"clients\": %s,\n", clients
  printf "    \"delay\": {\n"
  printf "      \"min\": %s,\n", delay_min
  printf "      \"max\": %s\n", delay_max
  printf "    }"
  i++
}
/^jws-app-/ {
  if (i) {printf "\n  },\n" }
  printf "  {\n"
  printf "    \"scheme\": \"http\",\n"
  printf "    \"host\": \"%s\",\n", $1
  printf "    \"port\": 80,\n"
  printf "    \"method\": \"POST\",\n"
  printf "    \"path\": \"%s\",\n", path
  printf "    \"headers\": {\n"
  printf "      \"Content-Type\": \"application/x-www-form-urlencoded\"\n"
  printf "    },\n"
  printf "    \"body\": \"summary=jws-app-tomcat8:+get+stuff+done&description=jws-app-tomcat8:+omg+so+many+things\",\n"
  printf "    \"keep-alive-requests\": %s,\n", ka_requests
  printf "    \"clients\": %s,\n", clients
  printf "    \"delay\": {\n"
  printf "      \"min\": %s,\n", delay_min
  printf "      \"max\": %s\n", delay_max
  printf "    }"
  i++
}
/^secure-jws-app-/ {
  if (i) {printf "\n  },\n" }
  printf "  {\n"
  printf "    \"scheme\": \"https\",\n"
  printf "    \"tls-session-reuse\": %s,\n", tls_session_reuse
  printf "    \"host\": \"%s\",\n", $1
  printf "    \"port\": 443,\n"
  printf "    \"method\": \"POST\",\n"
  printf "    \"path\": \"%s\",\n", path
  printf "    \"headers\": {\n"
  printf "      \"Content-Type\": \"application/x-www-form-urlencoded\"\n"
  printf "    },\n"
  printf "    \"body\": \"summary=secure-jws-app-tomcat8:+get+stuff+done&description=secure-jws-app-tomcat8:+omg+so+many+things\",\n"
  printf "    \"keep-alive-requests\": %s,\n", ka_requests
  printf "    \"clients\": %s,\n", clients
  printf "    \"delay\": {\n"
  printf "      \"min\": %s,\n", delay_min
  printf "      \"max\": %s\n", delay_max
  printf "    }"
  i++
}
/^127./ {
  if (i) {printf "\n  },\n" }
  printf "  {\n"
  printf "    \"scheme\": \"https\",\n"
  printf "    \"tls-session-reuse\": %s,\n", tls_session_reuse
  printf "    \"host\": \"%s\",\n", $1
  printf "    \"port\": 8443,\n"
  printf "    \"method\": \"GET\",\n"
  printf "    \"path\": \"%s\",\n", path
  printf "    \"keep-alive-requests\": %s,\n", ka_requests
  printf "    \"clients\": %s,\n", clients
  printf "    \"delay\": {\n"
  printf "      \"min\": %s,\n", delay_min
  printf "      \"max\": %s\n", delay_max
  printf "    }"
  i++
}
BEGIN { i=0; printf "[\n" }
END {
  if (i) { printf "\n  }" }
  printf "\n]\n"
}
