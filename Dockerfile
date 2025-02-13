FROM public.ecr.aws/lambda/ruby:3.3

COPY Gemfile Gemfile.lock ${LAMBDA_TASK_ROOT}/

RUN gem install bundler:2.6.3 && \
    bundle config set --local path 'vendor/bundle' && \
    bundle install

COPY lambda_handler.rb src ${LAMBDA_TASK_ROOT}/
CMD [ "lambda_handler.LambdaHandler.call" ]
