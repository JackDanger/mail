# encoding: utf-8
module Mail
  # The Message class provides a single point of access to all things to do with an
  # email message.
  # 
  # You create a new email message by calling the Mail::Message.new method, or just
  # Mail.new
  # 
  # A Message object by default has the following objects inside it:
  # 
  # * A Header object which contians all information and settings of the header of the email
  # * Body object which contains all parts of the email that are not part of the header, this
  #   includes any attachments, body text, mime parts etc.
  # 
  # ==Per RFC2822
  # 
  #  2.1. General Description
  # 
  #   At the most basic level, a message is a series of characters.  A
  #   message that is conformant with this standard is comprised of
  #   characters with values in the range 1 through 127 and interpreted as
  #   US-ASCII characters [ASCII].  For brevity, this document sometimes
  #   refers to this range of characters as simply "US-ASCII characters".
  # 
  #   Note: This standard specifies that messages are made up of characters
  #   in the US-ASCII range of 1 through 127.  There are other documents,
  #   specifically the MIME document series [RFC2045, RFC2046, RFC2047,
  #   RFC2048, RFC2049], that extend this standard to allow for values
  #   outside of that range.  Discussion of those mechanisms is not within
  #   the scope of this standard.
  # 
  #   Messages are divided into lines of characters.  A line is a series of
  #   characters that is delimited with the two characters carriage-return
  #   and line-feed; that is, the carriage return (CR) character (ASCII
  #   value 13) followed immediately by the line feed (LF) character (ASCII
  #   value 10).  (The carriage-return/line-feed pair is usually written in
  #   this document as "CRLF".)
  # 
  #   A message consists of header fields (collectively called "the header
  #   of the message") followed, optionally, by a body.  The header is a
  #   sequence of lines of characters with special syntax as defined in
  #   this standard. The body is simply a sequence of characters that
  #   follows the header and is separated from the header by an empty line
  #   (i.e., a line with nothing preceding the CRLF).
  class Message
    
    include Patterns
    include Utilities
    
    # Creates a new Mail::Message object through .new
    def initialize(*args, &block)
      @body = nil

      if args.flatten.first.respond_to?(:each_pair)
        init_with_hash(args.flatten.first)
      else
        init_with_string(args.flatten[0].to_s.strip)
      end

      if block_given?
        instance_eval(&block)
      end

      self
    end
    
    def deliver!
      Deliverable.perform_delivery!(self)
    end
    
    def <=>(other)
      if other.nil?
        1
      else
        self.date <=> other.date
      end
    end
    
    def ==(other)
      unless other.respond_to?(:encoded)
        false
      else
        self.encoded == other.encoded
      end
    end
    
    # Provides access to the raw source of the message as it was when it
    # was instantiated. This is set at initialization and so is untouched
    # by the parsers or decoder / encoders
    #
    # Example:
    # 
    #  mail = Mail.new('This is an invalid email message')
    #  mail.raw_source #=> "This is an invalid email message"
    def raw_source
      @raw_source
    end
    
    def raw_source=(value)
      @raw_source = value.to_crlf
    end
    
    def set_envelope( val )
      @raw_envelope = val
      @envelope = Mail::Envelope.new( val )
    end
    
    def set_envelope( val )
      @raw_envelope = val
      @envelope = Mail::Envelope.new( val )
    end
    
    # The raw_envelope is the From mikel@test.lindsaar.net Mon May  2 16:07:05 2009
    # type field that you can see at the top of any email that has come
    # from a mailbox
    def raw_envelope
      @raw_envelope
    end
    
    def envelope_from
      @envelope ? @envelope.from : nil
    end
    
    def envelope_date
      @envelope ? @envelope.date : nil
    end
    
    # Sets the header of the message object.
    # 
    # Example:
    # 
    #  mail.header = 'To: mikel@test.lindsaar.net\r\nFrom: Bob@bob.com'
    #  mail.header #=> <#Mail::Header
    def header=(value)
      @header = Mail::Header.new(value)
    end

    # Returns the header object of the message object. Or, if passed
    # a parameter sets the value.
    # 
    # Example:
    # 
    #  mail = Mail::Message.new('To: mikel\r\nFrom: you')
    #  mail.header #=> #<Mail::Header:0x13ce14 @raw_source="To: mikel\r\nFr...
    # 
    #  mail.header #=> nil
    #  mail.header 'To: mikel\r\nFrom: you'
    #  mail.header #=> #<Mail::Header:0x13ce14 @raw_source="To: mikel\r\nFr...
    def header(value = nil)
      value ? self.header = value : @header
    end
    
    # Provides a way to set custom headers, by passing in a hash
    def headers(hash = {})
      hash.each_pair do |k,v|
        header[k] = v
      end
    end
    
    # Sets the body object of the message object.
    # 
    # Example:
    # 
    #  mail.body = 'This is the body'
    #  mail.body #=> #<Mail::Body:0x13919c @raw_source="This is the bo...
    # 
    # You can also reset the body of an Message object by setting body to nil
    # 
    # Example:
    # 
    #  mail.body = 'this is the body'
    #  mail.body.encoded #=> 'this is the body'
    #  mail.body = nil
    #  mail.body.encoded #=> ''
    # 
    # If you try and set the body of an email that is a multipart email, then instead
    # of deleting all the parts of your email, mail will add a text/plain part to
    # your email:
    # 
    #  mail.add_file 'somefilename.png'
    #  mail.parts.length #=> 1
    #  mail.body = "This is a body"
    #  mail.parts.length #=> 2
    #  mail.parts.last.content_type.content_type #=> 'This is a body'
    def body=(value)
      case
      when value == nil
        @body = Mail::Body.new('')
      when @body && !@body.parts.empty?
        @body << Mail::Part.new(value)
      else
        @body = Mail::Body.new(value)
      end
      add_encoding_to_body
    end

    # Returns the body of the message object. Or, if passed
    # a parameter sets the value.
    # 
    # Example:
    # 
    #  mail = Mail::Message.new('To: mikel\r\n\r\nThis is the body')
    #  mail.body #=> #<Mail::Body:0x13919c @raw_source="This is the bo...
    # 
    #  mail.body 'This is another body'
    #  mail.body #=> #<Mail::Body:0x13919c @raw_source="This is anothe...
    def body(value = nil)
      if value
        self.body = value
        add_encoding_to_body
      else
        @body
      end
    end
    
    # Sets the to filed of the message header.
    # 
    # Example:
    # 
    #  mail.to = '"Mikel Lindsaar" <mikel@test.lindsaar.net>'
    #  mail.to #=> '"Mikel Lindsaar" <mikel@test.lindsaar.net>'
    def to=(value)
      header[:to] = value
    end
    
    # Returns the to field in the message header. Or, if passed
    # a parameter sets the value.
    # 
    # Example:
    # 
    #  mail.to = '"M L" <mikel@test.lindsaar.net>'
    #  mail.to.to_s #=> '"M L" <mikel@test.lindsaar.net>'
    #  mail.to.formatted #=> ['"M L" <mikel@test.lindsaar.net>']
    #  mail.to.addresses #=> ['mikel@test.lindsaar.net']
    def to(value = nil)
      value ? self.to = value : header[:to]
    end

    # Sets the from field in the message header.
    # 
    # Example:
    # 
    #  mail.from = '"Mikel Lindsaar" <mikel@test.lindsaar.net>'
    #  mail.from.to_s #=> '"Mikel Lindsaar" <mikel@test.lindsaar.net>'
    def from=(value)
      header[:from] = value
    end
    
    # Returns the from field in the message header. Or, if passed
    # a parameter sets the value.
    # 
    # Example:
    # 
    #  mail.from = '"Mikel Lindsaar" <mikel@test.lindsaar.net>'
    #  mail.from.to_s #=> '"Mikel Lindsaar" <mikel@test.lindsaar.net>'
    # 
    #  mail.from '"M L" <mikel@test.lindsaar.net>'
    #  mail.from.to_s #=> '"M L" <mikel@test.lindsaar.net>'
    #  mail.from.formatted #=> ['"M L" <mikel@test.lindsaar.net>']
    #  mail.from.addresses #=> ['mikel@test.lindsaar.net']
    def from(value = nil)
      value ? self.from = value : header[:from]
    end
    
    # Returns the list of addresses this message should be sent to by
    # collecting the addresses off the to, cc and bcc fields.
    # 
    # Example:
    # 
    #  mail.to = 'mikel@test.lindsaar.net'
    #  mail.cc = 'sam@test.lindsaar.net'
    #  mail.bcc = 'bob@test.lindsaar.net'
    #  mail.destinations.length #=> 3
    #  mail.destinations.first #=> 'mikel@test.lindsaar.net'
    def destinations
      [to, cc, bcc].map { |f| f.addresses if f }.compact.flatten
    end

    # Returns an array of addresses (the encoded value) in the From field,
    # if no From field, returns an empty array
    def from_addrs
      from ? from.formatted.compact.flatten : []
    end
    
    # Returns an array of addresses (the encoded value) in the To field,
    # if no To field, returns an empty array
    def to_addrs
      to ? to.formatted.compact.flatten : []
    end
    
    # Returns an array of addresses (the encoded value) in the Cc field,
    # if no Cc field, returns an empty array
    def cc_addrs
      cc ? cc.formatted.compact.flatten : []
    end
    
    # Returns an array of addresses (the encoded value) in the Bcc field,
    # if no Bcc field, returns an empty array
    def bcc_addrs
      bcc ? bcc.formatted.compact.flatten : []
    end
    
    # Sets the subject field in the message header.
    # 
    # Example:
    # 
    #  mail.subject = 'This is the subject'
    #  mail.subject.to_s #=> 'This is the subject'
    def subject=(value)
      header[:subject] = value
    end
    
    # Returns the subject field in the message header. Or, if passed
    # a parameter sets the value.
    # 
    # Example:
    # 
    #  mail.subject = 'This is the subject'
    #  mail.subject.to_s #=> 'This is the subject'
    # 
    #  mail.subject 'This is another subject'
    #  mail.subject.to_s #=> 'This is another subject'
    def subject(value = nil)
      value ? self.subject = value : header[:subject]
    end
    
    # Allows you to add an arbitrary header
    # 
    # Example:
    #
    #  mail['foo'] = '1234'
    #  mail['foo'].to_s #=> '1234'
    def []=(name, value)
      if name.to_s == 'body'
        self.body = value
      elsif name.to_s =~ /content[-_]type/i
        header[underscoreize(name)] = value
      else
        header[underscoreize(name)] = value
      end
    end

    # Allows you to read an arbitrary header
    # 
    # Example:
    #
    #  mail['foo'] = '1234'
    #  mail['foo'].to_s #=> '1234'
    def [](name)
      header[underscoreize(name)]
    end
    
    # Method Missing in this implementation allows you to set any of the
    # standard fields directly as you would the "to", "subject" etc.
    # 
    # Those fields used most often (to, subject et al) are given their
    # own method for ease of documentation and also to avoid the hook 
    # call to method missing.
    # 
    # This will only catch the known fields listed in:
    #
    #  Mail::Field::KNOWN_FIELDS
    #
    # as per RFC 2822, any ruby string or method name could pretty much
    # be a field name, so we don't want to just catch ANYTHING sent to
    # a message object and interpret it as a header.
    # 
    # This method provides all three types of header call to set, read
    # and explicitly set with the = operator
    # 
    # Examples:
    # 
    #  mail.comments = 'These are some comments'
    #  mail.comments.to_s #=> 'These are some comments'
    # 
    #  mail.comments 'These are other comments'
    #  mail.comments.to_s #=> 'These are other comments'
    # 
    # 
    #  mail.date = 'Tue, 1 Jul 2003 10:52:37 +0200'
    #  mail.date.to_s #=> 'Tue, 1 Jul 2003 10:52:37 +0200'
    # 
    #  mail.date 'Tue, 1 Jul 2003 10:52:37 +0200'
    #  mail.date.to_s #=> 'Tue, 1 Jul 2003 10:52:37 +0200'
    # 
    #
    #  mail.resent_msg_id = '<1234@resent_msg_id.lindsaar.net>'
    #  mail.resent_msg_id.to_s #=> '<1234@resent_msg_id.lindsaar.net>'
    # 
    #  mail.resent_msg_id '<4567@resent_msg_id.lindsaar.net>'
    #  mail.resent_msg_id.to_s #=> '<4567@resent_msg_id.lindsaar.net>'
    def method_missing(name, *args, &block)
      #:nodoc:
      # Only take the structured fields, as we could take _anything_ really
      # as it could become an optional field... "but therin lies the dark side"
      field_name = underscoreize(name).chomp("=")
      if Mail::Field::KNOWN_FIELDS.include?(field_name)
        if args.empty?
          header[field_name]
        else
          header[field_name] = args.first
        end
      else
        super # otherwise pass it on 
      end 
      #:startdoc:
    end 

    # Returns an FieldList of all the fields in the header in the order that
    # they appear in the header
    def header_fields
      header.fields
    end

    # Returns true if the message has a message ID field, the field may or may
    # not have a value, but the field exists or not.
    def has_message_id?
      header.has_message_id?
    end

    # Returns true if the message has a Date field, the field may or may
    # not have a value, but the field exists or not.
    def has_date?
      header.has_date?
    end

    # Returns true if the message has a Date field, the field may or may
    # not have a value, but the field exists or not.
    def has_mime_version?
      header.has_mime_version?
    end

    def has_content_type?
      !!content_type
    end
    
    def has_charset?
      !!charset
    end
    
    def has_transfer_encoding?
      transfer_encoding
    end

    # Creates a new empty Message-ID field and inserts it in the correct order
    # into the Header.  The MessageIdField object will automatically generate
    # a unique message ID if you try and encode it or output it to_s without
    # specifying a message id.
    # 
    # It will preserve the message ID you specify if you do.
    def add_message_id(msg_id_val = '')
      header['message-id'] = msg_id_val
    end
    
    # Creates a new empty Date field and inserts it in the correct order
    # into the Header.  The DateField object will automatically generate
    # DateTime.now's date if you try and encode it or output it to_s without
    # specifying a date yourself.
    # 
    # It will preserve any date you specify if you do.
    def add_date(date_val = '')
      header['date'] = date_val
    end
    
    # Creates a new empty Mime Version field and inserts it in the correct order
    # into the Header.  The MimeVersion object will automatically generate
    # DateTime.now's date if you try and encode it or output it to_s without
    # specifying a date yourself.
    # 
    # It will preserve any date you specify if you do.
    def add_mime_version(ver_val = '')
      header['mime-version'] = ver_val
    end
    
    # Adds a content type and charset if the body is US-ASCII
    # 
    # Otherwise raises a warning
    def add_content_type
      header['Content-Type'] = 'text/plain'
    end
    
    # Adds a content type and charset if the body is US-ASCII
    # 
    # Otherwise raises a warning
    def add_charset
      if body.only_us_ascii?
        content_type.parameters['charset'] = 'US-ASCII'
      else
        STDERR.puts("Non US-ASCII detected and no charset defined.\nDefaulting to UTF-8, set your own if this is incorrect.")
        content_type.parameters['charset'] = 'UTF-8'
      end
    end
    
    # Adds a transfer encoding
    # 
    # Otherwise raises a warning
    def add_transfer_encoding
      if body.only_us_ascii?
        header['Content-Transfer-Encoding'] = '7bit'
      else
        STDERR.puts("Non US-ASCII detected and no content-transfer-encoding defined.\nDefaulting to 8bit, set your own if this is incorrect.")
        header['Content-Transfer-Encoding'] = '8bit'
      end
    end
    
    # Returns the content transfer encoding of the email
    def transfer_encoding
      content_transfer_encoding
    end
    
    # Returns the content type
    def message_content_type
      content_type ? content_type.content_type : nil
    end
    
    # Returns the character set defined in the content type field
    def charset
      content_type ? content_type.parameters['charset'] : nil
    end

    # Sets the charset to the supplied value.  Will set the content type to text/plain if
    # it does not already exist
    def charset=(value)
      if content_type
        content_type.parameters['charset'] = value
      else
        self.content_type ['text', 'plain', {'charset' => value}]
      end
    end
    
    # Returns the main content type
    def main_type
      has_content_type? ? content_type.main_type : nil
    end
    
    # Returns the sub content type
    def sub_type
      has_content_type? ? content_type.sub_type : nil
    end
    
    # Returns the content type parameters
    def mime_parameters
      has_content_type? ? content_type.parameters : nil
    end
    
    # Returns true if the message is multipart
    def multipart?
      !!(main_type =~ /^multipart$/i)
    end
    
    # Returns true if the message is a multipart/report
    def multipart_report?
      multipart? && sub_type =~ /^report$/i
    end
    
    # Returns true if the message is a multipart/report; report-type=delivery-status;
    def delivery_status_report?
      multipart_report? && mime_parameters['report-type'] =~ /^delivery-status$/i
    end
    
    # returns the part in a multipart/report email that has the content-type delivery-status
    def delivery_status_part
      @delivery_stats_part ||= parts.select { |p| p.delivery_status_report_part? }.first
    end
    
    def bounced?
      delivery_status_part.bounced?
    end
    
    def action
      delivery_status_part.action
    end
    
    def final_recipient
      delivery_status_part.final_recipient
    end
    
    def error_status
      delivery_status_part.error_status
    end

    def diagnostic_code
      delivery_status_part.diagnostic_code
    end
    
    def remote_mta
      delivery_status_part.remote_mta
    end
    
    def retryable?
      delivery_status_part.retryable?
    end
    
    # Returns the current boundary for this message part
    def boundary
      mime_parameters ? mime_parameters['boundary'] : nil
    end
    
    # Returns an array of parts in the message
    def parts
      body.parts
    end
    
    # Returns an array of attachments in the email recursively
    def attachments
      body.parts.map do |p| 
        if p.parts.empty?
          p.attachment if p.attachment?
        else
          p.attachments
        end
      end.compact.flatten
    end

    def has_attachments?
      !attachments.empty?
    end
    
    # Accessor for html_part
    def html_part(&block)
      if block_given?
        @html_part = Mail::Part.new(&block)
        add_multipart_alternate_header
        add_part(@html_part)
      else
        @html_part
      end
    end
    
    # Accessor for text_part
    def text_part(&block)
      if block_given?
        @text_part = Mail::Part.new(&block)
        add_multipart_alternate_header
        add_part(@text_part)
      else
        @text_part
      end
    end
    
    # Helper to add a html part to a multipart/alternative email.  If this and
    # text_part are both defined in a message, then it will be a multipart/alternative
    # message and set itself that way.
    def html_part=(msg = nil)
      if msg
        @html_part = msg
      else
        @html_part = Mail::Part.new('Content-Type: text/html;')
      end
      add_multipart_alternate_header
      add_part(@html_part)
    end
    
    # Helper to add a text part to a multipart/alternative email.  If this and
    # html_part are both defined in a message, then it will be a multipart/alternative
    # message and set itself that way.
    def text_part=(msg = nil)
      if msg
        @text_part = msg
      else
        @text_part = Mail::Part.new('Content-Type: text/plain;')
      end
      add_multipart_alternate_header
      add_part(@text_part)
    end

    # Adds a part to the parts list or creates the part list
    def add_part(part)
      if body.parts.empty? && !self.body.decoded.blank?
         @text_part = Mail::Part.new('Content-Type: text/plain;')
         @text_part.body = body.decoded
         self.body << @text_part
         add_multipart_alternate_header
      end
      add_boundary
      self.body << part
    end

    # Allows you to add a part in block form to an existing mail message object
    # 
    # Example:
    # 
    #  mail = Mail.new do
    #    part :content_type => "multipart/alternative", :content_disposition => "inline" do |p|
    #      p.part :content_type => "text/plain", :body => "test text\nline #2"
    #      p.part :content_type => "text/html", :body => "<b>test</b> HTML<br/>\nline #2"
    #    end
    #  end
    def part(params = {})
      new_part = Part.new(params)
      yield new_part if block_given?
      add_part(new_part)
    end
    
    # Adds a file to the message.  You have two options with this method, you can
    # just pass in the absolute path to the file you want and Mail will read the file,
    # get the filename from the path you pass in and guess the mime type, or you
    # can pass in the filename as a string, and pass in the file data as a blob.
    # 
    # Example:
    # 
    #  m = Mail.new
    #  m.add_file('/path/to/filename.png')
    # 
    # or
    # 
    #  m = Mail.new
    #  m.add_file(:filename => 'filename.png', :data => File.read('/path/to/filename.png'))
    # 
    # The above two alternatives will produce the same email message.
    # 
    # Note also that if you add a file to an existing message, Mail will convert that message
    # to a MIME multipart email, moving whatever plain text body you had into it's own text
    # plain part.
    # 
    # Example:
    # 
    #  m = Mail.new do
    #    body 'this is some text'
    #  end
    #  m.multipart? #=> false
    #  m.add_file('/path/to/filename.png')
    #  m.multipart? #=> true
    #  m.parts.first.content_type.content_type #=> 'text/plain'
    #  m.parts.last.content_type.content_type #=> 'image/png'
    def add_file(options)
      convert_to_multipart unless self.multipart? || self.body.decoded.blank?
      add_multipart_mixed_header
      if options.is_a?(Hash)
        self.body << Mail::Part.new(options)
      else
        self.body << Mail::Part.new(:filename => options)
      end
    end

    def convert_to_multipart
      text = @body.decoded
      self.body = ''
      text_part = Mail::Part.new({:content_type => 'text/plain;',
                                  :body => text})
      self.body << text_part
    end

    # Encodes the message, calls encode on all it's parts, gets an email message
    # ready to send
    def ready_to_send!
      parts.each { |part| part.ready_to_send! }
      add_required_fields
    end
    
    def encode!
      STDERR.puts("Deprecated in 1.1.0 in favour of :ready_to_send! as it is less confusing with encoding and decoding.")
      ready_to_send!
    end
    
    # Outputs an encoded string representation of the mail message including
    # all headers, attachments, etc.  This is an encoded email in US-ASCII,
    # so it is able to be directly sent to an email server.
    def encoded
      ready_to_send!
      buffer = header.encoded
      buffer << "\r\n"
      buffer << body.encoded
      buffer
    end
    
    alias :to_s :encoded
    
    def decoded
      raise NoMethodError, 'Can not decode an entire message, try calling #decoded on the various fields and body or parts if it is a multipart message.'
    end
    
    # Returns true if this part is an attachment
    def attachment?
      find_attachment
    end
    
    # Returns the attachment data if there is any
    def attachment
      @attachment
    end
    
    # Returns the filename of the attachment
    def filename
      if attachment?
        attachment.filename
      else
        nil
      end
    end
    
    private

    #  2.1. General Description
    #   A message consists of header fields (collectively called "the header
    #   of the message") followed, optionally, by a body.  The header is a
    #   sequence of lines of characters with special syntax as defined in
    #   this standard. The body is simply a sequence of characters that
    #   follows the header and is separated from the header by an empty line
    #   (i.e., a line with nothing preceding the CRLF).
    # 
    # Additionally, I allow for the case where someone might have put whitespace
    # on the "gap line"
    def parse_message
      header_part, body_part = raw_source.split(/#{CRLF}#{WSP}*#{CRLF}/m, 2)
      self.header = header_part
      self.body   = body_part
    end
    
    def set_envelope_header
      if match_data = raw_source.to_s.match(/^From\s(#{TEXT}+)#{CRLF}(.*)/m)
        set_envelope(match_data[1])
        self.raw_source = match_data[2]
      end
    end

    def separate_parts
      body.split!(boundary)
    end
    
    def add_encoding_to_body
      unless content_transfer_encoding.blank?
        body.encoding = content_transfer_encoding.decoded
      end
    end
    
    def add_required_fields
      @body = Mail::Body.new('')    if body.nil?
      add_message_id                unless (has_message_id? || self.class == Mail::Part)
      add_date                      unless has_date?
      add_mime_version              unless has_mime_version?
      add_content_type              unless has_content_type?
      add_charset                   unless has_charset?
      add_transfer_encoding         unless has_transfer_encoding?
    end
    
    def add_multipart_alternate_header
      header['content-type'] = ContentTypeField.with_boundary('multipart/alternative').value
      body.boundary = boundary
    end
    
    def add_boundary
      unless body.boundary && boundary
        header['content-type'] = 'multipart/mixed' unless header['content-type']
        header['content-type'].parameters[:boundary] = ContentTypeField.generate_boundary
        body.boundary = boundary
      end
    end
    
    def add_multipart_mixed_header
      unless header['content-type']
        header['content-type'] = ContentTypeField.with_boundary('multipart/mixed').value
        body.boundary = boundary
      end
    end
    
    def init_with_hash(hash)
      passed_in_options = hash.with_indifferent_access
      self.raw_source = ''
      @header = Mail::Header.new
      @body = Mail::Body.new

      # Strip out the attachment headers and make an attachment
      if passed_in_options.has_key?(:filename)
        add_attachment(passed_in_options)
        passed_in_options.delete(:content_disposition)
        passed_in_options.delete(:content_type)
        passed_in_options.delete(:mime_type)
        passed_in_options.delete(:filename)
        passed_in_options.delete(:data)
      end
      
      passed_in_options.each_pair do |k,v|
        k = underscoreize(k).to_sym if k.class == String
        if k == :headers
          self.headers(v)
        else
          self[k] = v
        end
      end
    end
    
    def add_attachment(options_hash)
      @attachment = Mail::Attachment.new(options_hash)
      mime_type = options_hash[:content_type] || attachment.mime_type
      self.content_type = "#{mime_type}; filename=\"#{attachment.filename}\""
      self.content_transfer_encoding = "Base64"

      disposition = options_hash[:content_disposition] || "attachment"
      self.content_disposition = "#{disposition}; filename=\"#{attachment.filename}\""
      add_boundary
      self.body = attachment.encoded
    end
    
    def init_with_string(string)
      self.raw_source = string
      set_envelope_header
      parse_message
      separate_parts if multipart?
      if filename = attachment?
        encoding = content_transfer_encoding.encoding if content_transfer_encoding
        @attachment = Mail::Attachment.new(:filename => filename,
                                           :data => body.to_s,
                                           :encoding => encoding)
      end
    end
    
    # Returns the filename of the attachment (if it exists) or returns nil
    def find_attachment
      case
      when content_type && content_type.filename
        filename = content_type.filename
      when content_disposition && content_disposition.filename
        filename = content_disposition.filename
      when content_location && content_location.location
        filename = content_location.location
      else
        filename = nil
      end
      filename
    end

  end
end
