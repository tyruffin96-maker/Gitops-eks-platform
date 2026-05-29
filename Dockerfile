FROM nginx:alpine
COPY k8s/base/ /usr/share/nginx/html/
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
