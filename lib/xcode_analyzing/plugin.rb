module Danger
    class DangerXcodeAnalyzing < Plugin
        require 'Fileutils'
        require 'rexml/document'

        attr_accessor :diff_files
        def diff_files
            return diff_files = (git.modified_files - git.deleted_files) + git.added_files
        end

        attr_accessor :xcodebuild_workspace
        attr_accessor :xcodebuild_project_dir
        attr_accessor :xcodebuild_project
        attr_accessor :xcodebuild_scheme
        attr_accessor :xcodebuild_configuration
        attr_accessor :xcodebuild_target_sdk
        attr_accessor :xcodebuild_archs

        attr_accessor :analyzedResultsDir
        def analyzedResultsDir
            return @analyzedResultsDir
        end

        def report

            if xcodebuild_configuration.nil? || xcodebuild_configuration.empty?
                warn("(- -;;) cannot find configuration", sticky: false)
                return
            end

            if xcodebuild_scheme.nil? || xcodebuild_scheme.empty?
                warn("(- -;;) cannot find scheme", sticky: false)
                return
            end

            target_sdk = xcodebuild_target_sdk
            if xcodebuild_target_sdk.nil? || xcodebuild_target_sdk.empty?
                target_sdk = 'iphoneos'
            end
            
            archs = xcodebuild_archs
            if xcodebuild_archs.nil? || xcodebuild_archs.empty?
                archs = 'arm64'
            end

            if xcodebuild_project_dir.nil? || xcodebuild_project_dir.empty?
                puts "xcode project is root."
            else
                system "cd #{xcodebuild_project_dir}"
            end

            if xcodebuild_workspace.nil? || xcodebuild_workspace.empty?
                if xcodebuild_project.nil? || xcodebuild_project.empty?
                    warn("(- -;;) cannot find workspace or xcodeproj", sticky: false)
                    return
                else
                    system "xcodebuild analyze -project #{xcodebuild_project} -scheme #{xcodebuild_scheme} -configuration #{xcodebuild_configuration} -sdk #{target_sdk} CLANG_ANALYZER_OUTPUT=plist CLANG_ANALYZER_OUTPUT_DIR=\"$(pwd)/clang\" ARCHS=#{archs}"
                end
            else
                system "xcodebuild analyze -workspace #{xcodebuild_workspace} -scheme #{xcodebuild_scheme} -configuration #{xcodebuild_configuration} -sdk #{target_sdk} CLANG_ANALYZER_OUTPUT=plist CLANG_ANALYZER_OUTPUT_DIR=\"$(pwd)/clang\" ARCHS=#{archs}"
            end

            unless FileTest.exists? analyzedResultsDir
                fail("(・A・)!! #{analyzedResultsDir}が見当たりません、ビルドに失敗しているか無効なディレクトリ指定です", sticky: false)
                return
            end

            Dir.foreach(analyzedResultsDir) do |file|
                puts file
                if file.end_with?(".plist")
                    targetFileName = nil
                    doc = REXML::Document.new(File.new(analyzedResultsDir + "/" + file))
                    doc.elements.each("plist/dict/array") do |element|
                        element.elements.each("string") do |filename|
                            diff_files.each do |target|
                                if filename.text.include? target
                                    targetFileName = target
                                end
                            end
                        end
                        unless targetFileName == nil
                            element.elements.each("dict/array/dict/dict") do |child|
                                if child.elements['key'].text == 'line'
                                    element.elements.each("dict/array/dict") do |messages|
                                        messages.elements.each_with_index() do |key, index|
                                            if key.text == "message"
                                                offset = (index + 2) # <- 1始まり、かつ次の要素
                                                message = messages.elements[offset].text
                                                unless message.empty?
                                                    warn(message, file: targetFileName, line: child.elements['integer'].text.to_i)
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end
