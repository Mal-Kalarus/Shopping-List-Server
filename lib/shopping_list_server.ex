##############################################################################
# Assignment : 5
# Author     : MALGORZATA KALARUS
# Email      : mkalarus@uwo.ca
#
# The ShoppingListServer module implements a shopping list server,
# handling requests from clients and making use of the ShoppingListStore
# and UserStore to read and write data.
##############################################################################

defmodule ShoppingListServer do

  def start() do

    server_pid = self()

    # Spawn a linked UserStore process
    users_pid = spawn_link(UserStore, :start,[])

    # Spawn a linked ShoppingListStore process
    lists_pid = spawn_link(ShoppingListStore, :start, [])

    # Leave this here
    Process.register(self(), :server)

    # Start the message processing loop
    loop(users_pid, lists_pid, server_pid)
  end

  def loop(users, lists, server) do
    # Receive loop goes here
     receive do

       {caller, :new_user, username, password} ->
         spawn_link(fn -> new_user(caller, username, password, users, server) end)
         loop(users, lists, server)

       {caller, :list_users} ->
         spawn_link(fn -> list_users(caller, users, server) end)
         loop(users, lists, server)

       {caller, :shopping_list, username, password} ->
         spawn_link(fn -> shopping_list(caller, username, password, users, lists, server) end)
         loop(users, lists, server)

       {caller, :add_item, username, password, item} ->
         spawn_link(fn -> add_item(caller, username, password, item, users, lists, server) end)
         loop(users, lists, server)

       {caller, :delete_item, username, password, item} ->
         spawn_link(fn -> delete_item(caller, username, password, item, users, lists, server) end)
         loop(users, lists, server)

        {caller, :clear} ->
         spawn_link(fn -> clear(caller, users, lists, server) end)
         loop(users, lists, server)

         {caller, :exit} ->
           exit_call(caller)

       end
    # For each request that is received, you MUST spawn a new process
    # to handle it (either here, or in a helper method) so that the main
    # process can immediately return to processing incoming messages
    #
    # Note: use helper functions.  Implementing everything in a massive
    # function here will lose you marks.

  end

   # new_user helper function
  defp new_user(caller, username, password, users, server) do
    # sends message to the UserStore process to add a new user
    send(users, {self(), :add, username, password})
    #if user was added successfully
    receive do
      {_, :added, _} ->
        send(caller,{server, :ok, "User created successfully"})
     #else if user could not be added
      {_, :error, reason} ->
        send(caller, {server, :error, reason})
      #else if unexpected message received
      _-> send(caller, {server, :error, "An unknown error occured"})
    end
  end

  # list_users helper function
  defp list_users(caller, users, server)do
    # send message to UserStore process to get a sorted list of usernames
    send(users, {self(), :list})
    receive do
      {_, :user_list, flat_list} ->
      #if list was retrieved successfully
        send(caller,{server, :ok, flat_list})
      #if an unexpected message was returned return error message
      _-> send(caller,{server, :error, "An unknown error occured"})
    end
  end

  # shopping_list helper function
  defp shopping_list(caller, username, password, users, lists, server)do
    #send a message to the UserStore process to authenticate users
    send(users, {self(), :authenticate, username, password})
    receive do
      #if authentication fails, send following message
      {_, :auth_failed, _} ->
        send(caller, {server, :error, "Authentication failed"})
      #if authentication succeeds, send  message to ShoppingListStore process to fetch shoppng list
      {_, :auth_success, _} ->
        send(lists, {self(), :list, username})
          receive do
            #if the list is retrieved successfully
            {_, :list, _, items} ->
              send(caller, {server, :ok, items})
            # if an unexpected message was received
            _-> send(caller, {server, :error, "An unknown error occurred"})
          end
       # otherwise if unexpected message received
       _-> send(caller,{server, :error , "An unknown error occured"})
    end
  end

  # add_item helper function
  defp add_item(caller, username, password, item, users, lists, server) do
    #send message to UserStore to authenticate user
    send(users, {self(), :authenticate, username, password})
    receive do
      #if authentication fails, send following message
      {_, :auth_failed, _} ->
        send(caller, {server, :error, "Authentication failed"})
      #if authentication succeeds, send  message to ShoppingListStore process to add itme to users shopping list
      {_, :auth_success, username} ->
        send(lists, {self(), :add, username, item})
        receive do
            #if the item is added successfully, send following message
            {_, :added, _ , item} ->
              send(caller,{server, :ok ,"Item '" <> item <> "' added to shopping list"})
            #if item already exists, send following messages
            {_, :exists, _ , item} ->
              send(caller,{server, :error ,"Item '" <> item <> "' already exists"})
            #otherwise if an unexpected message was received
            _-> send(caller,{server, :error , "An unknown error occured"})
          end
      # otherwise if unexpected message received
      _-> send(caller,{server, :error , "An unknown error occured"})
      end
   end

  # delete_item helper function
  defp delete_item(caller, username, password, item, users, lists, server) do
    #send message to UserStore to authenticate user
    send(users, {self(), :authenticate, username, password})
    receive do
      #if authentication fails, send following message
      {_, :auth_failed, _} ->
        send(caller, {server, :error, "Authentication failed"})
      #if authentication succeeds, send  message to ShoppingListStore process to delete itme from users shopping list
      {_, :auth_success, username} ->
        send(lists, {self(), :delete, username, item})
          receive do
            #if the item is added successfully, send following message
            {_, :deleted, _, item} ->
              send(caller,{server, :ok ,"Item '" <> item <> "' deleted from shopping list"})
            #if item already exists, send following messages
            {_, :not_found, _, item} ->
              send(caller,{server, :error ,"Item '" <> item <> "' not found"})
            #otherwise if an unexpected message was received
            _-> send(caller,{server, :error , "An unknown error occured"})
           end
      # otherwise if unexpected message received
      _-> send(caller,{server, :error , "An unknown error occured"})
    end
  end

 # clear helper function
  defp clear(caller, users, lists, server) do
    #sends message to UserStore and ShoppingListStore processes to clear all data in the system
    send(users, {self(), :clear})
    receive do
      {_, :cleared} ->
        send(lists, {self(), :clear})
          receive do
            {_, :cleared} ->
              # if both responses are sucessful, return message
              send(caller, {server, :ok, "All data cleared"})
              # otherwise if unexpected message received
            _-> send(caller, {server, :error, "An unknown error occurred"})
          end
      # otherwise if unexpected message received
      _-> send(caller, {server, :error, "An unknown error occurred"})
    end
  end

  # exit_call function prints that the process is shutting down to the screen and terminates process
  defp exit_call(_caller) do
    IO.puts "ShoppingListServer shutting down"
    Process.exit(self(),:kill)
  end

end
