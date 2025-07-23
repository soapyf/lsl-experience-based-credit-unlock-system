// Admin tool for managing credits and unlocks for agents in an experience
// target_agent is set to owner as an example but an agent selector could be implemented
// If you use this code keep in mind that there is a limit of ~4096 characters for each keypair value so you should keep unlock names as short as possible

string target_agent;

key dataRead;
key dataWrite;

string mode;

#define DEFAULT_DATA ["credits", "0", "unlocks", ""]
#define CHANNEL -91516
#define BAD_JSON [JSON_INVALID, JSON_NULL]
#define PREFIX "data_"   // Prefix for experience data keys   "data_6f37a320-820e-426f-9e5c-716700e65afc" = {"credits": "0", "unlocks": ""}

default
{
    state_entry()
    {
        target_agent = llGetOwner();
    }

    touch_start(integer total_number)
    {
        if(llDetectedKey(0) == llGetOwner())
        {
            // Check the expereince for existing agent data
            dataRead = llReadKeyValue(PREFIX+target_agent);
        }
    }

    dataserver(key queryid, string data)
    {
        // Determine if the data read or write operation was successful
        integer result = (integer)llGetSubString(data, 0, 0);

        // Retrieve the JSON data from the response, alternatively retrieves the error message if result == 0
        string jsonData = llGetSubString(data, 2, -1);

        if(result)
        {
            // Read operations
            if(queryid == dataRead)
            {
                integer malformed;
                
                string current_credits = llJsonGetValue(jsonData, ["credits"]);
                string current_unlocks = llJsonGetValue(jsonData, ["unlocks"]);

                // Check the retrieved data structure 
                if(llListFindList(BAD_JSON, [current_credits]) != -1  || llListFindList(BAD_JSON, [current_unlocks]) != -1)
                {
                    malformed = TRUE;
                }

                // If either credits or unlocks are malformed, we will start a rewrite dialog
                if(malformed)
                {
                    llListen(CHANNEL, "", llGetOwner(), "");
                    llDialog(llGetOwner(), 
                        "Malformed data received for agent: " + (string)target_agent + "\n\n" +
                        "Would you like to reset the experience data to defaults?",
                        ["Yes", "No"], CHANNEL
                    );
                    //dataWrite = llUpdateKeyValue(target_agent,DEFAULT_DATA, FALSE, FALSE);
                }
                else 
                {
                    // Store current credits and unlocks in linkset data
                    llLinksetDataWrite("current_credits", current_credits);
                    llLinksetDataWrite("current_unlocks", current_unlocks);

                    // Notify the owner with a dialog containing the retrieved data
                    llListen(CHANNEL, "", llGetOwner(), "");
                    llDialog(llGetOwner(), 
                        "Experience Data Retrieved" + "\n\n" + 
                        "Agent: " + (string)target_agent + "\n" + 
                        "Credits: " + llLinksetDataRead("current_credits") + "\n" +

                        // Include the unlocks for demonstration but this will most likely get too long and cause an error when trying to display a dialog
                        "Unlocks: " + llLinksetDataRead("current_unlocks")
                        ,
                        ["Edit", "Reset", "Close"]
                        ,
                        CHANNEL
                    );
                }
            }
            
            // Write operations
            else if(queryid == dataWrite)
            {
                // Data write successful
                llOwnerSay("Experience data successfully created or updated.");
                llOwnerSay("Credits: " + llJsonGetValue(jsonData, ["credits"]));
                llOwnerSay("Unlocks: " + llJsonGetValue(jsonData, ["unlocks"]));
                llListenRemove(CHANNEL);
            }
            else
            {
                llOwnerSay("Data request was not recognized.");
                llOwnerSay("Query ID: " + (string)queryid);
                llOwnerSay("Data: " + jsonData);
                llListenRemove(CHANNEL);
            }
        }
        else 
        {
            // No experience key found for the agent
            if(jsonData == "14")
            {
                llOwnerSay("No experience data found for agent: " + (string)target_agent);
                llOwnerSay("Would you like to create new experience data for this agent?");
                llListen(CHANNEL, "", llGetOwner(), "");
                llDialog(llGetOwner(), 
                    "No experience data found for agent: " + (string)target_agent + "\n\n" +
                    "Would you like to create new experience data?",
                    ["Yes", "No"], CHANNEL
                );
            }
            // Handle error in data retrieval
            llOwnerSay("Failed to retrieve experience data for agent: " + (string)target_agent);
            llOwnerSay("Error: " + jsonData);
            llListenRemove(CHANNEL);
        }
    }

    listen(integer channel, string name, key id, string message)
    {
        //llOwnerSay(message);
        if(message == "Edit")
        {
            // Open the experience data editor dialog
            llDialog(llGetOwner(),
                "Edit Experience Data for Agent: " + (string)target_agent + "\n\n" +
                "Current Credits: " + llLinksetDataRead("current_credits") + "\n" +
                "Current Unlocks: " + llLinksetDataRead("current_unlocks") + "\n\n",
                ["Credits","Unlocks","Close"], CHANNEL
            );
        }
        else if(message == "Reset")
        {
            // Reset the experience data to defaults
            llDialog(llGetOwner(),
                "Reset user experience data to defaults?",
                ["Yes", "No"], CHANNEL
            );
        }
        else if(message == "Yes")
        {
            // Reset the experience data to defaults
            llOwnerSay("Experience data reset to defaults.");
            dataWrite = llUpdateKeyValue(PREFIX+target_agent, llList2Json(JSON_OBJECT,DEFAULT_DATA), FALSE, "");
        }
        else if(message == "Close" || message == "No" || message == "Cancel")
        {
            // Close the dialog
            llListenRemove(CHANNEL);
            mode = ""; // Reset mode
        }


        // Editor Menu
        else if(message == "Credits")
        {
            // Open a dialog to edit credits
            mode = "credits";
            llDialog(llGetOwner(),
                "Edit Credits for Agent: " + (string)target_agent + "\n\n" +
                "Current Credits: " + llLinksetDataRead("current_credits") + "\n\n",
                ["Add", "Remove", "Cancel"], CHANNEL
            );
        }
        else if(message == "Unlocks")
        {
            // Open a dialog to edit unlocks
            mode = "unlocks";
            llDialog(llGetOwner(),
                "Edit Unlocks for Agent: " + (string)target_agent + "\n\n" +
                "Current Unlocks: " + llLinksetDataRead("current_unlocks") + "\n\n",
                ["Add", "Remove", "Cancel"], CHANNEL
            );
            
        }
        else if(message == "Add")
        {
            if(mode == "credits")
            {
                // Prompt for amount to add to credits
                llTextBox(llGetOwner(), "Enter the amount to add to credits:", CHANNEL );
            }
            else if(mode == "unlocks")
            {
                // Prompt for unlocks to add
                llTextBox(llGetOwner(), "Enter the unlocks to add (comma-separated):", CHANNEL );
            }
            mode = "+" + mode; // Set mode to "+Credits" or "+Unlocks"
        }
        else if(message == "Remove")
        {
            if(mode == "credits")
            {
                // Prompt for amount to remove from credits
                llTextBox(llGetOwner(), "Enter the amount to remove from credits:", CHANNEL );
            }
            else if(mode == "unlocks")
            {
                // Prompt for unlocks to remove
                llTextBox(llGetOwner(), "Enter the unlocks to remove (comma-separated):", CHANNEL );
            }
            mode = "-" + mode; // Set mode to "-Credits" or "-Unlocks"
        }

        else if(message == "Save")
        {
            if(mode == "+credits")
            {
                // Add credits
                integer credits = (integer)llLinksetDataRead("current_credits");
                credits += (integer)llLinksetDataRead("temp_data");
                llOwnerSay("Adding "+ llLinksetDataRead("temp_data") + " credits to agent: " + (string)target_agent);
                dataWrite = llUpdateKeyValue(PREFIX+target_agent, llList2Json(JSON_OBJECT, ["credits", (string)credits, "unlocks", llLinksetDataRead("current_unlocks")]), FALSE, "");
            }
            else if(mode == "-credits")
            {
                // Remove credits
                integer credits = (integer)llLinksetDataRead("current_credits");
                credits -= (integer)llLinksetDataRead("temp_data");
                if(credits < 0) credits = 0; // Ensure credits do not go negative
                llOwnerSay("Removing " + llLinksetDataRead("temp_data") + " credits from agent: " + (string)target_agent);
                dataWrite = llUpdateKeyValue(PREFIX+target_agent, llList2Json(JSON_OBJECT, ["credits", (string)credits, "unlocks", llLinksetDataRead("current_unlocks")]), FALSE, "");
                
            }
            else if(mode == "+unlocks")
            {
                // Add unlocks
                list unlocksToAdd = llCSV2List(llLinksetDataRead("temp_data"));
                list currentUnlocks = llCSV2List(llLinksetDataRead("current_unlocks"));

                // Ensure no duplicates
                integer i = llGetListLength(unlocksToAdd);
                while(i--)
                {
                    string find = llList2String(unlocksToAdd, i);
                    if(llListFindList(currentUnlocks, [find]) == -1)
                    {
                        currentUnlocks += [find];
                    } 
                    else 
                    {
                        unlocksToAdd = llDeleteSubList(unlocksToAdd, i, i); // Remove duplicates from the list
                        llOwnerSay(find + " already unclocked for agent");
                    }
                }
                llOwnerSay("Adding unlocks: " + llDumpList2String(unlocksToAdd, ", ") + " to agent: " + (string)target_agent);
                dataWrite = llUpdateKeyValue(PREFIX+target_agent, llList2Json(JSON_OBJECT, ["credits", llLinksetDataRead("current_credits"), "unlocks", llList2CSV(currentUnlocks)]), FALSE, "");
                
            }
            else if(mode == "-unlocks")
            {
                // Remove unlocks
                list unlocksToRemove = llCSV2List(llLinksetDataRead("temp_data"));
                list currentUnlocks = llCSV2List(llLinksetDataRead("current_unlocks"));
                
                integer i = llGetListLength(unlocksToRemove);
                while(i--)
                {
                    string find = llList2String(unlocksToRemove, i);
                    integer index = llListFindList(currentUnlocks, [find]);
                    if(index != -1)
                    {
                        currentUnlocks = llDeleteSubList(currentUnlocks, index, index);
                    }
                }
                llOwnerSay("Removing unlocks: " + llDumpList2String(unlocksToRemove, ", ") + " from agent: " + (string)target_agent);
                dataWrite = llUpdateKeyValue(PREFIX+target_agent, llList2Json(JSON_OBJECT, ["credits", llLinksetDataRead("current_credits"), "unlocks", llList2CSV(currentUnlocks)]), FALSE, "");
                
            }
            mode = ""; // Reset mode
        }
        else
        {
            if(llListFindList(["+credits","+unlocks","-credits","-unlocks"],[mode]) > -1)
            {
                llLinksetDataWrite("temp_data", message);
                llDialog(llGetOwner(), "Do you want to save this change?", ["Save", "Cancel"], CHANNEL );
            }
            else 
            {

            }
        }
    }
}
