# ActiveModel for representing the backend files (special ones and source files too)
class BackendFile
  include ActiveModel::Model

  BUFFER_SIZE = 40960

  attr_accessor :name
  attr_reader :response

  validates :name, presence: true
  validate :backend_file_errors

  def initialize(attributes = {})
    super
    @file ||= nil
    @response ||= {}
    @last_read_query = {}
  end

  # Sets the content File object for that model instance, calculates the right response data
  def file=(input_stream)
    Tempfile.open('backend_file', "#{Rails.root}/tmp", encoding: 'ascii-8bit') do |tempfile|
      buffer = ''
      tempfile.write(buffer) while input_stream.read(BUFFER_SIZE, buffer)
      @file = tempfile
    end
  end

  # Sets the content File object from a path
  def file_from_path(path)
    @file = File.open(path)
    @response = { type: MIME::Types.type_for(@file.basename).first.content_type, status: 200, length: @file.length }
    @file.close
  end

  # Returns a File object (closed) that have the content of the Backend file
  def file(query = {})
    if @file.nil? && valid? # Read it from Backend
      Suse::Backend.get(full_path(query)) do |backend_response|
        Tempfile.open('backend_file', Dir.tmpdir, encoding: 'ascii-8bit') do |tempfile|
          backend_response.read_body do |buffer|
            tempfile.write(buffer)
          end
          @file = tempfile
          @response = { type: backend_response['Content-Type'], status: backend_response.code, length: @file.length }
        end
      end
      @last_read_query = query
    end
    @file
  rescue Exception => e
    @backend_file_errors = e.message
    valid?
    nil
  end

  # Converts file into a String if it's valid
  def to_s(query = {})
    file(query)
    !@file.nil? && valid? ? File.open(@file.path).read : nil
  end

  # Reloads from Backend the file content
  def reload
    @file = nil
    @response = {}
    file(@last_read_query)
  end

  # Tries to save the file to the backend and return the response, otherwise will raise an Exception
  # If "content" parameter is provided then is passed directly to the backend, otherwise it creates
  # a temp file and then send it to the backend
  def save!(query = {}, content = nil)
    backend_response = nil
    if content
      backend_response = Suse::Backend.put(full_path(query), content)
    else
      @file.open
      backend_response = Suse::Backend.put(full_path(query), @file)
      @response = { type: backend_response['Content-Type'], status: backend_response.code, length: backend_response.content_length }
      @file.close
    end
    backend_response
  end

  # Tries to save the file to the backend. Returns nil if some Exception is raised
  def save(query = {}, content = nil)
    save!(query, content)
  rescue Exception => e
    @backend_file_errors = e.message
    valid?
    nil
  end

  # Tries to destroy the file from the backend, freeze the object and return the response, otherwise will raise an Exception
  def destroy!(query = {})
    response = Suse::Backend.delete(full_path(query))
    freeze
    response
  end

  # Tries to destroy the file from the backend. Returns nil if some Exception is raised
  def destroy(query = {})
    destroy!(query)
  rescue Exception => e
    @backend_file_errors = e.message
    valid?
    nil
  end

  # TODO: Replace SuseBackend.build_query_from_hash with this function asap
  def self.query_from_list(params, key_list = [])
    params = params.slice(*key_list)
    "?#{params.to_query}"
  end

  private

  # Validation of errors perfoming commands on the backend
  def backend_file_errors
    unless @backend_file_errors.blank?
      errors.add(:content, @backend_file_errors)
    end
  end
end
