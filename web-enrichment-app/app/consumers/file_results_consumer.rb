class FileResultsConsumer < ApplicationConsumer
  def consume
    messages.each do |message|
      data = message.payload
      source_file = SourceFile.find(data['source_file_id'])
      
      if data['status'] == 'completed'
        source_file.update!(status: 'processed', processed_at: Time.current)
      else
        source_file.update!(status: 'failed', error_message: data['error'])
      end
    end
  end
end