// Admin tool for managing credits and unlocks for agents in an experience
// target_agent is set to owner as an example but an agent selector could be implemented
// If you use this code keep in mind that there is a limit of ~4096 characters for each keypair value so you should keep unlock names as short as possible
// Some code in this script requires the firestorm LSL preprocessor to work correctly

#define CHANNEL -91516
#define BAD_JSON [JSON_INVALID, JSON_NULL]
#define PREFIX "data_"   // Prefix for experience data keys   "data_6f37a320-820e-426f-9e5c-716700e65afc" = {"credits": "0", "unlocks": ""}

// json values that you want treated as numbers need to have a number included in the DEFAULT_DATA list otherwise they will be treated as CSV's
list DEFAULT_DATA = ["credits", "0", "unlocks", "", "fruit", "0"];

string target_agent;
string mode;

key dataRead;
key dataWrite;


write_experience_data()
{
    list data;
    integer i = llGetListLength(DEFAULT_DATA);
    integer x; for(; x < i; x += 2)
    {
        string name = llList2String(DEFAULT_DATA, x);
        string value = llLinksetDataRead(name);
        data += [name, value];
    }
    dataWrite = llUpdateKeyValue(PREFIX+target_agent, llList2Json(JSON_OBJECT, data), FALSE, "");
}

integer read_json_data(string json)
{
    integer malformed;
    integer i = llGetListLength(DEFAULT_DATA);
    integer x; for(; x < i; x += 2)
    {
        string name = llList2String(DEFAULT_DATA, x);
        string value = llJsonGetValue(json, [name]);
        //if(value != "")
        {
            if(llListFindList(BAD_JSON, [value]) != -1){
                malformed = TRUE;
            } else {
                llLinksetDataWrite(name, value);

                // Create buttons for the dialog
                string buttons = llLinksetDataRead("buttons");
                if(buttons == ""){ buttons = name; } 
                else { buttons += "," + name; }
                llLinksetDataWrite("buttons", buttons);
            }
        }
    }
    if(malformed) {
        return FALSE;
    }
    return TRUE;
}

dialog_menu(string menu, string text)
{
    list buttons = llCSV2List(llLinksetDataRead("buttons"));
    // Preform some dialog text if not provided
    if(text == ""){
        text = "Experience Data for Agent secondlife:///app/agent/"+target_agent+"/about \n\n";
        
        integer i = llGetListLength(buttons);
        integer x; for(; x < i; x++)
        {
            string button = llList2String(buttons, x);
            text += llList2String(buttons, x) + ": " + llLinksetDataRead(button) + "\n";
        }
    }

    
    llListen(CHANNEL, "", llGetOwner(), "");
    if(menu == "main")
    {
        llDialog(llGetOwner(), text, ["Edit", "Reset", "Close"], CHANNEL);
    }
    else if(menu == "edit")
    {
        llDialog(llGetOwner(), text, ["Close"]+buttons, CHANNEL );
    }
    else if(menu == "confirm")
    {
        llListen(CHANNEL, "", llGetOwner(), "");
        llDialog(llGetOwner(), text, ["Yes", "No"], CHANNEL);
    }
}
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
            llLinksetDataReset();
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
                if(read_json_data(jsonData))
                {
                    dialog_menu("main","");
                }
                else 
                {
                    dialog_menu("confirm","Malformed data received for agent: " + (string)target_agent + "\n\n" + "Would you like to reset the experience data to defaults?");
                }
            }
            
            // Write operations
            else if(queryid == dataWrite)
            {
                // Data write successful
                llOwnerSay("Experience data successfully created or updated.");
                llListenRemove(CHANNEL);
            }
            else
            {
                // Unrecognized query ID
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
                dialog_menu("confirm","No experience data found for agent: " + (string)target_agent + "\n\n" + "Would you like to create new experience data?");
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
            dialog_menu("edit","");
        }
        else if(message == "Reset")
        {
            // Reset the experience data to defaults
            dialog_menu("confirm","Reset user experience data to defaults?");
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
        else if(llListFindList(llCSV2List(llLinksetDataRead("buttons")), [message]) != -1)
        {
            llOwnerSay("Editing " + message + " for agent: " + (string)target_agent);
            mode = message; // Set mode to the selected button
            integer value = (integer)llLinksetDataRead(message);
            llDialog(llGetOwner(),
                "Edit "+message+" for Agent: " + (string)target_agent + "\n\n" +
                "Current "+message+": " + llLinksetDataRead(message) + "\n\n",
                ["Add", "Remove", "Cancel"], CHANNEL
            );
        }
        else if(message == "Add")
        {
            // Prompt for amount to add
            llTextBox(llGetOwner(), "Enter item(s)/amount to add to "+mode+":", CHANNEL );
            mode = "+" + mode; // Set mode to addition, e.g. "+credits" or "+unlocks"
        }
        else if(message == "Remove")
        {
            // Prompt for amount to remove
            llTextBox(llGetOwner(), "Enter item(s)/amount to remove from "+mode+":", CHANNEL );
            mode = "-" + mode; // Set mode to removal, e.g. "-credits" or "-unlocks"
        }

        else if(message == "Save")
        {
            string modifier = llGetSubString(mode, 0, 0);
            string tmode = llGetSubString(mode, 1, -1); // Remove the "+" or "-" from the mode
            string current_value = llLinksetDataRead(tmode); // Get the current value for the mode
            string new_value = llLinksetDataRead("temp_data"); // Get the new value from temp_data
            integer isNumeric = llListFindList(["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"], [llGetSubString(current_value, 0, 0)]);
            if(modifier == "+")
            {
                if(isNumeric > -1){ llOwnerSay("number+"); // Debugging output
                    // assume value is a number
                    integer added_value = (integer)current_value + (integer)new_value;
                    llLinksetDataWrite(tmode, (string)added_value);
                } else { llOwnerSay("CSV+"); // Debugging output
                    // Add unlocks
                    list unlocksToAdd = llCSV2List(new_value);
                    list currentUnlocks = llCSV2List(current_value);

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
                    llOwnerSay("Adding " + llDumpList2String(unlocksToAdd, ", ") + " to agent: " + (string)target_agent);
                    llLinksetDataWrite(tmode, llList2CSV(currentUnlocks));
                }
                write_experience_data();
            }
            else if(modifier == "-")
            {
                if(isNumeric > -1){ llOwnerSay("number-"); // Debugging output
                    // assume value is a number
                    integer subtracted_value = (integer)current_value -(integer)new_value;
                    if(subtracted_value < 0) subtracted_value = 0; // Ensure value does not go negative
                    llOwnerSay("Removing "+ new_value + " "+tmode+" from agent: " + (string)target_agent);
                    llLinksetDataWrite(tmode, (string)subtracted_value);
                } else { llOwnerSay("CSV-"); // Debugging output
                    // assume its a CSV list
                    // Remove unlocks
                    list unlocksToRemove = llCSV2List(llLinksetDataRead("temp_data"));
                    list currentUnlocks = llCSV2List(llLinksetDataRead("unlocks"));
                    
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
                    llLinksetDataWrite("unlocks", llList2CSV(currentUnlocks));
                }
                write_experience_data();
            }
            else if(mode == "-unlocks")
            {
                // Remove unlocks
                list unlocksToRemove = llCSV2List(new_value);
                list currentUnlocks = llCSV2List(current_value);
                
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
                llLinksetDataWrite("unlocks", llList2CSV(currentUnlocks));
                write_experience_data();
                
            }
            mode = ""; 
        }
        else
        {
            if(llListFindList(["+","-"],[llGetSubString(mode,0,0)]) > -1)
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
