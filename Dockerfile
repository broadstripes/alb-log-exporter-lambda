FROM public.ecr.aws/lambda/ruby:3.3

COPY Gemfile Gemfile.lock ${LAMBDA_TASK_ROOT}/

RUN gem install bundler:2.6.3 && \
    bundle config set --local path 'vendor/bundle' && \
    bundle config set --local deployment true && \
    bundle config set --local without development && \
    bundle install

COPY lambda_handler.rb ${LAMBDA_TASK_ROOT}/
COPY lib ${LAMBDA_TASK_ROOT}/lib
CMD [ "lambda_handler.LambdaHandler.call" ]
