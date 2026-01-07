# Build stage
FROM hexpm/elixir:1.17.3-erlang-27.2-debian-bookworm-20241202 AS build

RUN apt-get update && apt-get install -y build-essential git nodejs npm && rm -rf /var/lib/apt/lists/*

WORKDIR /app

ENV MIX_ENV=prod

# Install hex + rebar
RUN mix local.hex --force && mix local.rebar --force

# Install deps
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod
RUN mix deps.compile

# Build assets
COPY assets assets
COPY priv priv
RUN cd assets && npm install && npm run deploy
RUN mix phx.digest

# Build release
COPY config config
COPY lib lib
RUN mix compile
RUN mix release

# Runtime stage
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y libstdc++6 openssl libncurses5 locales && rm -rf /var/lib/apt/lists/*

ENV LANG=en_US.UTF-8
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

WORKDIR /app

COPY --from=build /app/_build/prod/rel/phoenix_sqlite_demo ./

ENV DATABASE_PATH=/data/phoenix_sqlite_demo.db

# Create data directory for SQLite
RUN mkdir -p /data

EXPOSE 4000

CMD ["bin/phoenix_sqlite_demo", "start"]
