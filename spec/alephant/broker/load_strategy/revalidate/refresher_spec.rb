require "spec_helper"

RSpec.describe Alephant::Broker::LoadStrategy::Revalidate::Refresher do
  subject { described_class.new(component_meta) }

  let(:component_meta) do
    Alephant::Broker::ComponentMeta.new("test", "test_batch", {})
  end

  let(:cache_double)      { instance_double(Alephant::Broker::Cache::Client) }
  let(:sqs_double)        { instance_double(AWS::SQS, :queues => sqs_queues_double) }
  let(:sqs_queue_double)  { instance_double(AWS::SQS::Queue) }
  let(:sqs_queues_double) { instance_double(AWS::SQS::QueueCollection, :url_for => "example.com", :[] => sqs_queue_double) }

  let(:config)  { { :aws_account_id => "12345", :sqs_queue_name => "bob" } }

  let(:cache_key)          { subject.send(:cache_key) }
  let(:inflight_cache_key) { subject.send(:inflight_cache_key) }

  before do
    allow_any_instance_of(Logger).to receive(:info)
    allow_any_instance_of(Logger).to receive(:debug)
    allow(Alephant::Broker::Cache::Client).to receive(:new).and_return(cache_double)
    allow(AWS::SQS).to receive(:new).and_return(sqs_double)
    allow(Alephant::Broker).to receive(:config).and_return(config)
  end

  describe "#refresh" do
    context "when there is already a 'inflight' message in the cache" do
      before do
        expect(cache_double)
          .to receive(:get)
          .with(subject.send(:inflight_cache_key))
          .and_return("true")
      end

      it "does nothing" do
        expect(cache_double).to_not receive(:set)

        subject.refresh
      end
    end

    context "when there is NOT already a 'inflight' message in the cache" do
      before do
        expect(cache_double)
          .to receive(:get)
          .with(inflight_cache_key)
          .and_return(nil)
      end

      it "adds a message to the SQS queue, ",
        "and puts a 'inflight' message in the cache" do
        expect(cache_double)
          .to receive(:set)
          .with(inflight_cache_key, true)

        expect(sqs_queue_double)
          .to receive(:send_message)

        subject.refresh
      end
    end
  end
end
