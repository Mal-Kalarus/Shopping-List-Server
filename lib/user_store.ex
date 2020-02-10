##############################################################################
# Assignment : 5
# Author     : MALGORZATA KALARUS
# Email      : mkalarus@uwo.ca
#
# UserStore module manages a database of users, storing their usernames and passwords
##############################################################################

import User

defmodule UserStore do

  # Path to the user database file
  # Don't forget to create this directory if it doesn't exist
  @database_directory "db"

  # Name of the user database file
  @user_database "users.txt"

  # Note: you will spawn a process to run this store in
  # ShoppingListServer.  You do not need to spawn another process here
  def start() do

    # Load your users and start your loop
    loop()
  end

  defp loop() do
    File.mkdir_p!(@database_directory)
    receive do

      {caller, :clear} ->
        clear(caller)
        loop()

      {caller,:list} ->
        list(caller)
        loop()

      {caller, :add, username, password} ->
        add(caller, username, password)
        loop()

      {caller, :authenticate, username, password} ->
        authenticate(caller, username, password)
        loop()

      {caller, :exit} ->
        exit_call(caller)

      # Always handle unmatched messages
      # Otherwise, they queue indefinitely
      _ ->
        loop()
    end

  end


  # clear function removes all users from the database(both in memory and on disk)
  defp clear(caller) do
    File.rm_rf Path.join(@database_directory, @user_database)
    # return response to caller
    send(caller, {self(), :cleared})
  end


  # list function retrieves a sorted list of all usernames in the database
  defp list(caller) do
    # create the file if it doesnt already exist
    File.touch!(user_database())
    #store the content of file into list
    raw_list = File.stream!(user_database())
      |> Enum.to_list
      # split raw list entries into username and password from username:password
      user_list =
        Enum.map(raw_list, fn user ->
          user_split = String.split(user,":")
          # extract username
          Enum.take(user_split,1)
          end)
          #flatten the list of lists into one list
          flat_list = List.flatten(user_list)
    #returns list to the caller
    send(caller, {self(), :user_list, flat_list})
  end


  # add function  adds a new user to list if it does not already exist
  defp add(caller, username, password) do
    # creates a new file if it does not already exist
    File.touch!(user_database())
    # parse the username from text file, load file content into list
    raw_list =
      File.stream!(user_database())
        |> Enum.to_list
        # split raw list entries into username and password from username:password
        user_list =
          Enum.map(raw_list, fn user ->
            user_split = String.split(user,":")
             # extract username
              Enum.take(user_split,1)
            end)
          #flatten the list of lists into one list
           flat_list = List.flatten(user_list)

      # check if user is in the database list
      user_item_full = username

    if Enum.member?(flat_list,user_item_full) do
         send(caller,{self(), :error, "User already exists"})
    else
          # hash the password
          hashed_pass = hash_password(password)
          # adds user to list
          append_list = [username <> ":" <> hashed_pass <> "\n"] ++ raw_list
          # sort the list in alphabetical order
          return_list = Enum.sort(append_list)
          # saves database to file
          File.write(user_database(), return_list)
        end
        # return to caller the user struct that has been added
        send(caller, {self(), :added, %User{username: username, password: hash_password(password)}})
  end


  # authenticate function hashes the provided password and compares it to the users hashed password in the database
  defp authenticate(caller, username, password) do
    # creates a new file if it does not already exist
    File.touch!(user_database())
    # need to first parse the username from text file
    raw_list =
      File.stream!(user_database())
        |> Enum.to_list
      # hash password and form the new entry in the form username:hash
      hash = hash_password(password)
      auth = username <> ":" <> hash <> "\n"

      # if entry is in the list then return the atom :auth_success else return :auth_failed
      if Enum.member?(raw_list, auth) do

        send(caller, {self(), :auth_success, username})
      else

        send(caller, {self(), :auth_failed, username})
      end

  end

  # exit_call function prints that the process is shutting down to the screen and terminates process
  defp exit_call(_caller) do
    IO.puts "UserStore shutting down"
    Process.exit(self(),:kill)
  end

  # Path to the user database
  defp user_database(), do: Path.join(@database_directory, @user_database)

  # Use this function to hash your passwords
  defp hash_password(password) do
    hash = :crypto.hash(:sha256, password)
    Base.encode16(hash)
  end

end
