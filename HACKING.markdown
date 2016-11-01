# Development environment

This instructions will help you to build development quickly.

* Download MackLogic server in to current directory

```shell
curl <mark logic url> -O MarkLogic-RHEL7-8.0-5.8.x86_64.rpm
```

* Build docker image

```shell
docker build -t marklogic:8 .
```

* Start MarkLogic server inside docker

```shell
docker run -t -i --name oook -p 7997:7997 -p 7999:7999 -p 8000:8000 -p 8001:8001 -p 8002:8002 -p 8889:8889 marklogic:8
```

* You can pause MarkLogic server

```shell
docker stop oook
```

* You can resume MarkLogic server

```shell
docker start -i -a oook
```

* Open http://localhost:8001/ in your browser and follow installation steps

** Databases / Create
   - TutorialDB

** Groups / Default / App Servers / Create XDBC
   - CiderAny
   - /data
   - 8889

* Run Emacs

```shell
cask exec emacs -Q -l scripts/init.el test.xqy -f cider-jack-in
```
