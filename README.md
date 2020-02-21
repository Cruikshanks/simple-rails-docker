# Simple Rails Docker example

Created as part of getting myself back into (and hopefully sticking with!) Docker.

I wanted to create a very basic rails app running in a Docker container. But as a minimum I also wanted the app talking to a database outside of the container.

Docker has <https://docs.docker.com/compose/rails/> which covered what I needed to do for the most part by using Docker Compose.

There were some tweaks I needed to make along the way though to get it to work. The key one is ensuring a password is set in `docker-compose.yml` for postgres, and that this is matched in rails `config/database.yml`.

## Build

I feel the guide complicates things a little bit by using the web docker container to first generate the rails app. It's a handy way to avoid needing any dependencies on your host machine, but I think most folks would have an existing rails app they want to use.

So ignoring those steps, if you were to grab this project as is, first command would be

```bash
docker-compose build
```

This should build 2 images based on `docker-compose.yml`; the web app and PostgreSQL 10.

```bash
docker image ls

REPOSITORY                TAG                 IMAGE ID            CREATED             SIZE
simple-rails-docker_web   latest              51b25dbb053f        About an hour ago   843MB
postgres                  10                  530129daf9a9        13 hours ago        255MB
ruby                      2.4.2               2a867526d472        2 years ago         687MB
```

## Run

To start the environment (both web and db container) use `docker-compose up`.

If the first time it won't complete successfully because you need to create the database in postgres

```bash
docker-compose run web rake db:create
```

This makes a connection to the web app container and then in it calls `rake db:create`. I then found I had to ctrl+c, and run `docker-compose up` again.

## Contributing

If you think I'm doing something wrong and it pains you not to tell me, then by all means create an issue. But this seriously is just a small throwaway app!

## License

This information is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

> If you don't add a license it's neither free or open!
