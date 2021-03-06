# Copyright (C) 2016  Kouhei Sutou <kou@clear-code.com>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA

module Groonga
  class Client
    module Request
      class Generic
        def initialize(parameters=nil, extensions=[])
          @parameters = parameters
          @extensions = extensions
          extend(*@extensions) unless @extensions.empty?
        end

        def command_name
          self.class.command_name
        end

        def response
          @reponse ||= create_response
        end

        def parameter(name, value)
          add_parameter(OverwriteMerger,
                        RequestParameter.new(name, value))
        end

        def flags_parameter(name_or_names, value)
          if name_or_names.is_a?(Array)
            names = name_or_names
          else
            names = [name_or_names]
          end
          add_parameter(OverwriteMerger,
                        FlagsParameter.new(names, value))
        end

        def values_parameter(name_or_names, values)
          if name_or_names.is_a?(Array)
            names = name_or_names
          else
            names = [name_or_names]
          end
          add_parameter(OverwriteMerger,
                        ValuesParameter.new(names, values))
        end

        def to_parameters
          if @parameters.nil?
            {}
          else
            @parameters.to_parameters
          end
        end

        def extensions(*modules, &block)
          modules << Module.new(&block) if block
          if modules.empty?
            self
          else
            create_request(@parameters, @extensions | modules)
          end
        end

        private
        def add_parameter(merger_class, parameter)
          merger = merger_class.new(@parameters, parameter)
          create_request(merger, @extensions)
        end

        def create_request(parameters, extensions)
          self.class.new(parameters, extensions)
        end

        def create_response
          open_client do |client|
            response = client.execute(command_name, to_parameters)
            raise ErrorResponse.new(response) unless response.success?
            response
          end
        end

        def open_client
          Client.open do |client|
            yield(client)
          end
        end
      end

      class RequestParameter
        def initialize(name, value)
          @name = name
          @value = value
        end

        def to_parameters
          case @value
          when Symbol
            value = @value.to_s
          when String
            return {} if @value.empty?
            value = @value
          when Numeric
            value = @value.to_s
          when NilClass
            return {}
          else
            value = @value
          end
          {
            @name => value,
          }
        end
      end

      class ValuesParameter
        def initialize(names, values)
          @names = names
          @values = values
        end

        def to_parameters
          case @values
          when ::Array
            return {} if @values.empty?
            values = @values.collect(&:to_s).join(", ")
          when Symbol
            values = @values.to_s
          when String
            return {} if /\A\s*\z/ === @values
            values = @values
          when NilClass
            return {}
          else
            values = @values
          end
          parameters = {}
          @names.each do |name|
            parameters[name] = values
          end
          parameters
        end
      end

      class FlagsParameter
        def initialize(names, flags)
          @names = names
          @flags = flags
        end

        def to_parameters
          case @flags
          when ::Array
            return {} if @flags.empty?
            flags = @flags.collect(&:to_s).join("|")
          when Symbol
            flags = @flags.to_s
          when String
            return {} if /\A\s*\z/ === @flags
            flags = @flags
          when NilClass
            return {}
          else
            flags = @flags
          end
          parameters = {}
          @names.each do |name|
            parameters[name] = flags
          end
          parameters
        end
      end

      class ParameterMerger
        def initialize(parameters1, parameters2)
          @parameters1 = parameters1
          @parameters2 = parameters2
        end
      end

      class OverwriteMerger < ParameterMerger
        def to_parameters
          if @parameters1.nil?
            if @parameters2.nil?
              {}
            else
              @parameters2.to_parameters
            end
          else
            if @parameters2.nil?
              @parameters1.to_parameters
            else
              @parameters1.to_parameters.merge(@parameters2.to_parameters)
            end
          end
        end
      end
    end
  end
end
