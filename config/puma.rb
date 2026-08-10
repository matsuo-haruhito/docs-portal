threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
threads threads_count, threads_count

port ENV.fetch("PORT", 3000)

# 本番では WEB_CONCURRENCY で worker 数を制御する。
# MRI の GVL 制約を回避し、マルチコアを活用する。
# コンテナのレプリカ数で水平スケールする場合は 0 (single process) でもよい。
workers ENV.fetch("WEB_CONCURRENCY", 0)

# worker を使う場合は preload で CoW メモリ共有を活用する
preload_app! if ENV.fetch("WEB_CONCURRENCY", 0).to_i > 0

plugin :tmp_restart
plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"]

pidfile ENV["PIDFILE"] if ENV["PIDFILE"]
