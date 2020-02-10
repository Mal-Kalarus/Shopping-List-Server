##############################################################################
# Assignment : 5
# Author     : MALGORZATA KALARUS
# Email      : mkalarus@uwo.ca
#
# The ShoppingListStore module manages shopping lists for users.
##############################################################################

defmodule ShoppingListStore do

  # Path to the shopping list files (db/lists/*)
  # Don't forget to create this directory if it doesn't exist
  @database_directory Path.join("db", "lists")

  # Note: you will spawn a process to run this store in
  # ShoppingListServer.  You do not need to spawn another process here
  def start() do
    # Call your receive loop
    loop()
  end

  defp loop() do
    File.mkdir_p!(@database_directory)
    receive do

      {caller, :clear} ->
        clear(caller)
        loop()

      {caller,:list, username} ->
        list(caller, username)
        loop()


      {caller, :add, username, item} ->
        add(caller, username, item)
        loop()

      {caller, :delete, username, item} ->
        delete(caller, username, item)
        loop()

      {caller, :exit} ->
        exit_call(caller)

      # Always handle unmatched messages
      # Otherwise, they queue indefinitely
      _ ->
        loop()
    end

  end

  # Implemented for you
  defp clear(caller) do
    File.rm_rf @database_directory
    send(caller, {self(), :cleared})
  end

  # list function loads the user's shopping list from db/lists/USERNAME.txt
  defp list(caller, username) do
    File.touch!(user_db(username))
    items = File.stream!(user_db(username))
      |> Stream.map(&String.trim/1)
      |> Enum.to_list

    #IO.inspect items
    # returns username and items and atom :list to caller
    send(caller, {self(), :list, username,items})
  end
  # add function adds a new item to list if it does not already exist
  defp add(caller, username, item) do
    #create new file if it does not already exist
    File.touch!(user_db(username))
    # load text file to list
    list =
      File.stream!(user_db(username))
        |> Enum.to_list
    # add new line char to item
    item_full = item <> "\n"
    # if item is present in list retun that it does exist to caller else append it to list
    if Enum.member?(list,item_full) do
          #IO.puts "YES"
         send(caller,{self(), :exists, username, item})
       else
          #IO.puts "NO"
          #Append item to the list
          append_list = [item <> "\n"] ++ list
          #IO.inspect append_list

          #Sort the list alphabetically
          final = Enum.sort(append_list)
          #IO.inspect final

          #Save the sorted list to the file
          File.write(user_db(username), final)

        end
        #return atom :added , usernaem and item to the caller
        send(caller, {self(), :added, username, item})
  end

  # delete functio deletes item from the list if it exists
  defp delete(caller, username, item) do
    #create new file if it does not already exist
    File.touch!(user_db(username))
    #Get everything from the text file line by line and add it to list
    list =
      File.stream!(user_db(username))
        |> Enum.to_list
    # add the new line char to the item to be compared in list
    item_full = item <> "\n"
    # check to see if item is in list, if it is there then delete item from list
    if Enum.member?(list,item_full) do
          #IO.puts "YES"
          delete_from_list = list -- [item <> "\n"]
          #IO.inspect delete_from_list

          #remove file and write new one with updated list
          File.rm_rf! user_db(username)
          File.write(user_db(username), delete_from_list)
            #return atom :deleted and username, item to the caller
          send(caller, {self(), :deleted, username, item})
      else
          #IO.puts "NO"
          send(caller, {self(), :not_found, username, item})
          end
  end

# exit_call function prints that the process is shutting down to the screen and terminates process
  defp exit_call(_caller) do
    IO.puts "ShoppingListStore shutting down"
    Process.exit(self(),:kill)
  end

  # Path to the shopping list file for the specified user
  # (db/lists/USERNAME.txt)
  defp user_db(username), do: Path.join(@database_directory, "#{username}.txt")

end
