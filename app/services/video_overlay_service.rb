# frozen_string_literal: true

# Service for applying text overlays to videos using FFmpeg
class VideoOverlayService
  class Error < StandardError; end

  def self.apply_overlay(draft)
    return unless draft.media_url.present?
    return unless draft.metadata['overlay_text'].present?

    text = draft.metadata['overlay_text']
    video_url = draft.media_url

    # Download video to temp file
    input_path = Rails.root.join('tmp', "overlay_input_#{SecureRandom.hex(8)}.mp4")
    output_path = Rails.root.join('tmp', "overlay_output_#{SecureRandom.hex(8)}.mp4")

    begin
      Rails.logger.info "[VideoOverlayService] Downloading video from #{video_url}"

      # Download video file
      system("curl -s -L '#{video_url}' -o '#{input_path}'")

      unless File.exist?(input_path) && File.size(input_path) > 0
        raise Error, 'Failed to download video file'
      end

      Rails.logger.info "[VideoOverlayService] Applying text overlay: #{text}"

      # FFmpeg command to overlay text at bottom center
      # fontsize 48, white font, black border for readability, positioned near bottom center
      escaped_text = text.gsub("'", "'\\''")
      ffmpeg_cmd = "ffmpeg -y -i '#{input_path}' -vf \"drawtext=text='#{escaped_text}':fontsize=48:fontcolor=white:borderw=2:bordercolor=black:x=(w-text_w)/2:y=h-80\" -c:a copy '#{output_path}'"

      Rails.logger.info "[VideoOverlayService] Running FFmpeg command"

      system(ffmpeg_cmd)

      # Better logging - check if output file exists and its size
      if File.exist?(output_path)
        file_size = File.size(output_path)
        Rails.logger.info "[VideoOverlayService] FFmpeg completed - output file exists, size: #{file_size} bytes"
        
        # Upload the overlaid video
        new_url = upload_overlaid_video(output_path)

        if new_url.present?
          draft.update!(media_url: new_url)
          Rails.logger.info "[VideoOverlayService] Successfully applied overlay, new URL: #{new_url}"
        else
          raise Error, 'Failed to upload overlaid video'
        end
      else
        Rails.logger.error "[VideoOverlayService] FFmpeg output file NOT found at: #{output_path}"
        raise Error, 'FFmpeg failed to produce output'
      end
    rescue => e
      Rails.logger.error "[VideoOverlayService] Failed to apply overlay: #{e.message}"
    ensure
      # Clean up temp files
      File.delete(input_path) if File.exist?(input_path)
      File.delete(output_path) if File.exist?(output_path)
    end
  end

  def self.upload_overlaid_video(file_path)
    return unless File.exist?(file_path)

    # Copy to public storage folder and return relative URL
    storage_dir = Rails.root.join('public', 'storage', 'overlays')
    FileUtils.mkdir_p(storage_dir) unless Dir.exist?(storage_dir)

    dest_filename = "overlay_#{SecureRandom.hex(8)}.mp4"
    dest_path = storage_dir.join(dest_filename)
    FileUtils.cp(file_path, dest_path)

    "/storage/overlays/#{dest_filename}"
  rescue => e
    Rails.logger.error "[VideoOverlayService] Upload error: #{e.message}"
    nil
  end
end
