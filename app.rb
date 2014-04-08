# encoding: UTF-8

require 'sinatra'
require 'sinatra/sequel'
require 'json'
require 'httparty'
require 'mail'

require 'pp'

def required_env_var(env)
  (ENV[env] || raise("Missing #{env} env var"))
end

class Object
  def tapp
    tap {|o| pp o }
  end
end


module Railscamp
class Fifteen < Sinatra::Base

  SUBMISSION_DEADLINE = Time.new(2014,4,12,0,0,0,"+10:00").utc
  TICKET_PRICE_CENTS = required_env_var("TICKET_PRICE_CENTS").to_i
  TICKET_PRICE_CURRENCY = "AUD"
  TENT_TICKETS = required_env_var("TENT_SIZE").to_i

  configure :development do
    require 'sinatra/reloader'
    register Sinatra::Reloader

    set :pin, {
      publishable_key: required_env_var('PIN_TEST_PUBLISHABLE_KEY'),
      secret_key: required_env_var('PIN_TEST_SECRET_KEY'),
      api: 'test',
      api_root: 'https://test-api.pin.net.au/1'
    }
  end

  configure :production do
    set :pin, {
      publishable_key: required_env_var('PIN_LIVE_PUBLISHABLE_KEY'),
      secret_key: required_env_var('PIN_LIVE_SECRET_KEY'),
      api: 'live',
      api_root: 'https://api.pin.net.au/1'
    }
  end

  register Sinatra::SequelExtension

  migration "create the inital tables" do
    database.create_table :entrants do
      primary_key :id
      Time :created_at, null: false
      String :name, null: false
      String :email, null: false
      String :dietary_reqs, text: true
      TrueClass :wants_bus, null: false
      TrueClass :tent, null: false, default: false

      String :cc_name, null: false
      String :cc_address, null: false
      String :cc_city, null: false
      String :cc_post_code, null: false
      String :cc_state, null: false
      String :cc_country, null: false
      String :card_token, null: false

      String :ip_address, null: false
      Time   :chosen_at
      Time   :chosen_notified_at
    end

    database.create_table :scholarship_entrants do
      primary_key :id
      Time :created_at, null: false
      String :name, null: false
      String :email, null: false
      String :dietary_reqs, text: true
      TrueClass :wants_bus, null: false

      String :scholarship_pitch, null:false, text: true
      String :scholarship_github, null: false

      String :ip_address, null: false
      Time   :chosen_at
      Time   :chosen_notified_at
    end
  end

  migration "add charge columns" do
    database.add_column :entrants, :charge_token, String
  end

  migration "add ticket type column" do
    database.add_column :entrants, :ticket_type, String
    database.add_column :entrants, :notes, String, text: true
  end


  migration "add bedding and tshirt" do
    database.add_column :entrants, :tshirt_size, String
    database.add_column :entrants, :wants_bedding, TrueClass
  end

  migration "create the bedding_payments table" do
    database.create_table :bedding_payments do
      primary_key :id
      Time :created_at, null: false
      String :cc_name, null: false
      String :cc_address, null: false
      String :cc_city, null: false
      String :cc_post_code, null: false
      String :cc_state, null: false
      String :cc_country, null: false
      String :card_token, null: false
      String :ip_address, null: false
      String :charge_token
    end
  end

  migration "add email to bedding_payments" do
    database.add_column :bedding_payments, :email, String
  end

  class Entrant < Sequel::Model
    PUBLIC_ATTRS = [
      :name, :email, :dietary_reqs, :wants_bus,
      :cc_name, :cc_address, :cc_city, :cc_post_code, :cc_state, :cc_country,
      :card_token, :ip_address,
      :ticket_type, :notes,
      :wants_bedding, :tshirt_size, :tent
    ]

    CHARGE_ATTRS = [ :charge_token ]
    OPTIONAL_ATTRS = [ :notes, :ticket_type, :wants_bedding, :tshirt_size, :dietary_reqs ]

    set_allowed_columns *[ PUBLIC_ATTRS, CHARGE_ATTRS ].flatten
    plugin :validation_helpers

    def self.submitted_before_deadline
      filter { created_at >= SUBMISSION_DEADLINE }
    end
    def self.unchosen
      filter(chosen_at: nil)
    end
    def self.chosen
      exclude(chosen_at: nil)
    end
    def self.with_email(email)
      filter(email: email.to_s.downcase).first
    end

    def self.tent_campers
      filter(tent: true)
    end

    def self.bunk_campers
      filter(tent: false)
    end

    def needs_extras?
      wants_bedding.nil? || tshirt_size.nil?
    end

    def update_extras!(bedding_string, tshirt_size)
      wants_bedding = !! bedding_string[/bedding pack/]
      update wants_bedding: wants_bedding, tshirt_size: tshirt_size
    end

    def validate
      super
      validates_presence PUBLIC_ATTRS - OPTIONAL_ATTRS
    end

    def before_save
      self.created_at = Time.now.utc
    end

    def choose!
      update(chosen_at: Time.now.utc)
    end

    def set_charge_token!(token)
      update charge_token: token
    end
    def charged?
      charge_token
    end
    def self.uncharged
      filter(charge_token: nil)
    end


    def self.create_without_cc!(name, email, ticket_type, notes=nil)
      create(name: name,
             email: email,
             wants_bus: true,
             cc_name: 'xxx',
             cc_address: 'xxx',
             cc_city: 'xxx',
             cc_post_code: 'xxx',
             cc_state: 'xxx',
             cc_country: 'xxx',
             card_token: 'xxx',
             ip_address: 'xxx',
             ticket_type: ticket_type,
             notes: notes
            )
    end
  end


  module PayableModel
    CC_ATTRS = [
      :email, :cc_name, :cc_address, :cc_city, :cc_post_code, :cc_state, :cc_country,
      :card_token, :ip_address
    ]

    def set_charge_token!(token)
      update charge_token: token
    end
    def charged?
      charge_token
    end
  end

  class BeddingPayment < Sequel::Model
    include PayableModel
    plugin :validation_helpers

    def validate
      super
      validates_presence CC_ATTRS
    end

    def before_create
      self.created_at = Time.now.utc
    end
  end


  class ScholarshipEntrant < Sequel::Model
    PUBLIC_ATTRS = [
      :name, :email, :dietary_reqs, :wants_bus,
      :scholarship_github, :scholarship_pitch
    ]

    set_allowed_columns *PUBLIC_ATTRS
    plugin :validation_helpers

    def validate
      super
      validates_presence PUBLIC_ATTRS - [:dietary_reqs]
    end

    def before_save
      self.created_at = Time.now.utc
    end
  end

 



  helpers do
    def partial(name, locals={})
      erb name, layout: false, locals: locals
    end

    def h(text)
      Rack::Utils.escape_html(text)
    end

    def ensure_host!(host, scheme, status)
      unless request.host == host && request.scheme == scheme
        redirect "#{scheme}://#{host}#{request.path}", status
      end
    end
  end

  configure :production do
    before do
      case request.path
      when "/register", %w{^/pay}
        ensure_host! "secure.ruby.org.au", 'https', 302
      else
        ensure_host! "bne15.railscamps.org", 'http', 301
      end
    end
  end


  class Pin
    include HTTParty
    format :json
    base_uri Railscamp::Fifteen.settings.pin[:api_root]
    basic_auth Railscamp::Fifteen.settings.pin[:secret_key], ''
  end

  class EntrantCharger
    def charge!(entrant)
      if entrant.charged?
        raise("Entrant #{entrant.id} #{entrant.email} has already been charged")
      end
      body = Pin.post("/charges", body: params(entrant))
      if response = body['response']
        entrant.set_charge_token!(response['token'])
        response
      else
        entrant.errors.add("credit card", "charging failed")
        raise "Charge failed for entrant #{entrant.id} #{entrant.email}: \n#{body.inspect}"
      end
    end
    def params(entrant)
      {
        email: entrant.email,
        description: "Railscamp XV Brisbane",
        amount: TICKET_PRICE_CENTS,
        currency: TICKET_PRICE_CURRENCY,
        ip_address: entrant.ip_address,
        card_token: entrant.card_token
      }
    end
  end


  class PinCharger
    def initialize(param_overrides = {})
      @default_params = {
        description: "Railscamp XV Brisbane",
        amount: TICKET_PRICE_CENTS,
        currency: TICKET_PRICE_CURRENCY,
      }.merge(param_overrides)
    end
    def charge!(payable_model)
      if payable_model.charged?
        raise("#{payable_model.class.name} #{payable_model.id} has already been charged")
      end
      body = Pin.post("/charges", body: params(payable_model))
      if response = body['response']
        payable_model.set_charge_token!(response['token'])
        response
      else
        payable_model.errors.add("credit card", "charging failed")
        raise "Charge failed for payable_model #{payable_model.id}: \n#{body.inspect}"
      end
    end
    def params(payable_model)
      @default_params.merge({
        email: payable_model.email,
        ip_address: payable_model.ip_address,
        card_token: payable_model.card_token
      })
    end
  end


  class EntrantMailer
    def mail!(entrant)
      if entrant.mailed?
        raise("already mailed #{entrant.id} #{entrant.email}")
      end
    end
  end


  get '/' do
    erb :home
  end

  get '/register' do
    @tents_available = (Entrant.tent_campers.count < TENT_TICKETS)
    puts "DSFARGEG #{Entrant.tent_campers.count} - #{@tents_available}"
    erb :register
  end
  get '/scholarship' do
    erb :scholarship
  end

  post '/register' do
    STDERR.puts JSON.generate(params)
    entrant = Entrant.new(params[:entrant])
    if entrant.valid?
      entrant.save
      redirect "/✌"
    else
      @errors = entrant.errors
      erb :register
    end
  end


  post '/scholarship' do
    STDERR.puts JSON.generate(params)
    entrant = ScholarshipEntrant.new(params[:entrant])
    entrant.ip_address = request.ip
    if entrant.valid?
      entrant.save
      redirect "/✌"
    else
      @errors = entrant.errors
      erb :scholarship
    end
  end

  get '/✌' do
    erb :thanks
  end


  get '/pay_for_bedding' do
    @bedding_payment = BeddingPayment.new
    erb(:pay_for_bedding)
  end

  post '/pay_for_bedding' do
    STDERR.puts JSON.generate(params)

    # Save the bedding_payment
    @bedding_payment = BeddingPayment.new(params[:bedding_payment])

    unless @bedding_payment.valid?
      @errors = @bedding_payment.errors
      return erb(:pay_for_bedding)
    end

    @bedding_payment.save

    # Try to charge their card
    begin
      PinCharger.new(description: "Railscamp XV Bedding", amount: 12_00).charge!(@bedding_payment)
    rescue Exception => e
      STDERR.puts "Charge error: #{e.inspect}"
      @errors = @bedding_payment.errors
      return erb(:pay_for_bedding)
    end

    erb(:paid)
  end

end
end
