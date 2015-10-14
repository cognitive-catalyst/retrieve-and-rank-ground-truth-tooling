#!/usr/bin/env bash

# Vincent Dowling
# Watson Ecosystem
# migrateGt.sh
#
# Script that migrates ground truth to an instance
# Input: <cfg_file>, <solr_cluster_id>, <solr_collection_name>, <gt_xml_file>, <temp_dir>
#
# The script does things in the following order:
#   1) Converts a GT_SNAPSHOT_XML file into a tab delimited .txt file
#   2) Splits the tab-delimited .txt file into a training file and testing file
#   3) Creates a relevance file based on the contents of the training file
#   4) Trains a ranker using the relevance file
#
# The config file:
#   - Must be a .cfg file with each line of the following format: A=B
#   - Must define the following variables: RETRIEVE_AND_RANK_BASE_URL, RETRIEVE_AND_RANK_USERNAME, RETRIEVE_AND_RANK_PASSWORD, SOLR_COLLECTION_NAME, SOLR_CLUSTER_ID
#
# The gt_xml file:
#   - Should be the GT_SNAPSHOT_XML file that is downloaded from the training module in experience manager
#
# The temp_dir:
#   - Must be an existing directory
#   - Directory need not be empty, but the script will overwrite any contents that corresponds to the names of files below
#   - Best practice is to create a new working directory each time


# PARAMETER: <none>
# Install requirements for this script
install_requirements () {
    echo "[unix] Installing python dependency requests..."
    pip install -U requests 1> /dev/null
    echo "[unix] Installing python dependency argparse..."
    pip install -U argparse 1> /dev/null
    echo "[unix] Installing python dependency lxml..."
    pip install -U lxml 1> /dev/null
}


# Exit if a variable does not exist
variable_exists () {
    local VARIABLE_NAME=$1
    local VARIABLE=$2
    if [ ! -n "$VARIABLE_NAME" ]; then
        echo "[unix] No variable name passed in..."
    fi
    if [ ! -n "$VARIABLE" ]; then
        echo "[unix] variable=$VARIABLE_NAME does not exist. Exiting with status code 1"
        exit 1
    fi
}


# Source the config file and check to see that the expected variables exist
source_config_file () {
    local CFG_FILE=$1
    variable_exists "CONFIG_FILE" $CFG_FILE
    source $CFG_FILE
    variable_exists "RETRIEVE_AND_RANK_BASE_URL" $RETRIEVE_AND_RANK_BASE_URL
    variable_exists "RETRIEVE_AND_RANK_USERNAME" $RETRIEVE_AND_RANK_USERNAME
    variable_exists "RETRIEVE_AND_RANK_PASSWORD" $RETRIEVE_AND_RANK_PASSWORD
}


file_exists () {
    local FILE=$1
    if [ ! -e $FILE ]; then
        echo "[unix] file=$FILE does not exist. Exiting with status code 1"
        exit 1
    fi
}


directory_exists () {
    local DIR_NAME=$1
    if [ ! -d "$DIR_NAME" ]; then
        echo "[unix] directory=$DIR_NAME does not exist. Exiting with status code 1"
        exit 1
    fi
}


cluster_exists_and_is_ready () {
    local PRINT_CLUSTER_INFO_SCRIPT=$1
    file_exists $PRINT_CLUSTER_INFO_SCRIPT
    CLUSTER_STATE=$(python $PRINT_CLUSTER_INFO_SCRIPT $2 $3 $4 $5)
    if [[ "$CLUSTER_STATE" != "READY" ]]; then
        echo "[unix] Solr Cluster with URL=$2, USERNAME=$3, PASSWORD=$4, CLUSTER_ID=$5 does not exist or is not ready"
        echo "[unix] Exiting with status code 1"
        exit 1
    fi
}


# Exits if it cannot find the collection
contains_collection () {
    local PYTHON_SCRIPT=$1
    file_exists $PYTHON_SCRIPT
    local COLLECTION_NAME=$2
    RESPONSE=$(curl -s -u $RETRIEVE_AND_RANK_USERNAME:$RETRIEVE_AND_RANK_PASSWORD -d \
        "action=list&wt=json" "$RETRIEVE_AND_RANK_BASE_URL/v1/solr_clusters/$SOLR_CLUSTER_ID/solr/admin/collections")
    CONTAINS_COLLECTION=$(python $PYTHON_SCRIPT $RESPONSE $COLLECTION_NAME)
    if [[ "$CONTAINS_COLLECTION" != "CONTAIN" ]]; then
        echo "[unix] Could not find collection=$COLLECTION_NAME. Exiting with status code 1"
        exit 1
    fi
}


# Prompt for a variable
prompt_for_variable () {
    echo $1
    read $2
}


# Prerequisites
echo "[unix] Starting script migrateGt.sh..."
set -e


# Validate lib/bin directories
LIB_DIRECTORY=lib
BIN_DIRECTORY=bin
directory_exists $LIB_DIRECTORY
directory_exists $BIN_DIRECTORY


# Validate existence of python scripts
PYTHON_DIRECTORY=$BIN_DIRECTORY/python
XML_TO_GT_SCRIPT=$PYTHON_DIRECTORY/xml_to_ground_truth_file.py
SPLIT_TRAIN_TEST_SCRIPT=$PYTHON_DIRECTORY/split_train_test.py
RELEVANCE_FILE_SCRIPT=$PYTHON_DIRECTORY/generate_relevance_file.py
TRAINING_SCRIPT=$PYTHON_DIRECTORY/train_improved.py
PRINT_CLUSTER_INFO_SCRIPT=$PYTHON_DIRECTORY/print_solr_cluster_status.py
CONTAINS_COLLECTION_SCRIPT=$PYTHON_DIRECTORY/contains_collection.py
directory_exists $PYTHON_DIRECTORY
file_exists $XML_TO_GT_SCRIPT
file_exists $SPLIT_TRAIN_TEST_SCRIPT
file_exists $RELEVANCE_FILE_SCRIPT
file_exists $TRAINING_SCRIPT
file_exists $PRINT_CLUSTER_INFO_SCRIPT
file_exists $CONTAINS_COLLECTION_SCRIPT


# Install dependencies
echo "-------------------------------"
echo "[unix] Installing required dependencies..."
install_requirements
echo "[unix] Dependencies installed..."


# Validate arguments
CFG_FILE=$1
SOLR_CLUSTER_ID=$2
SOLR_COLLECTION_NAME=$3
GT_XML_FILE=$4
TEMP_DIR=$5
source_config_file $CFG_FILE
cluster_exists_and_is_ready $PRINT_CLUSTER_INFO_SCRIPT $RETRIEVE_AND_RANK_BASE_URL $RETRIEVE_AND_RANK_USERNAME \
    $RETRIEVE_AND_RANK_PASSWORD $SOLR_CLUSTER_ID
contains_collection $CONTAINS_COLLECTION_SCRIPT $SOLR_COLLECTION_NAME
directory_exists $TEMP_DIR
file_exists $GT_XML_FILE


# Convert gt_xml to .txt file
echo "-------------------------------"
echo "[unix] Transforming GT_SNAPSHOT_XML_FILE=$GT_XML_FILE into a CSV/Text file..."
TEMP_QUESTIONS_FILE=$TEMP_DIR/gt_questions.txt
python $XML_TO_GT_SCRIPT -i $GT_XML_FILE -o $TEMP_QUESTIONS_FILE --remove-escape --primary-only
file_exists $TEMP_QUESTIONS_FILE
echo "[unix] GT_SNAPSHOT_XML_FILE successfully transformed to CSV..."


# Split training data and validate the output
echo "-------------------------------"
echo "[unix] Splitting questions from input_file=$TEMP_QUESTIONS_FILE into train/test split"
python $SPLIT_TRAIN_TEST_SCRIPT -i $TEMP_QUESTIONS_FILE --ask-for-percentage
TRAIN_QUESTION_FILE=$TEMP_DIR/gt_questions_train.txt
file_exists $TRAIN_QUESTION_FILE
TEST_QUESTION_FILE=$TEMP_DIR/gt_questions_test.txt
file_exists $TEST_QUESTION_FILE
echo "[unix] Questions successfully split into training_file=$TRAIN_QUESTION_FILE and test_file=$TEST_QUESTION_FILE..."


# Generate relevance file
echo "-------------------------------"
echo "[unix] Generating relevance file from INPUT_QUESTION_FILE=$TRAIN_QUESTION_FILE..."
TRAINING_RELEVANCE_FILE=$TEMP_DIR/gt_questions_train_relevance.csv
python $RELEVANCE_FILE_SCRIPT -i $TRAIN_QUESTION_FILE -o $TRAINING_RELEVANCE_FILE
file_exists $TRAINING_RELEVANCE_FILE
echo "[unix] Relevance file successfully created..."


# Train ranker
echo "-------------------------------"
prompt_for_variable "Enter a name for your ranker: " RANKER_NAME
echo "[unix] Training ranker using relevance_file=$RELEVANCE_OUTPUT_FILE..."
RETRIEVE_AND_RANK_CREDENTIALS=$RETRIEVE_AND_RANK_USERNAME:$RETRIEVE_AND_RANK_PASSWORD
python $TRAINING_SCRIPT -u $RETRIEVE_AND_RANK_CREDENTIALS -i $TRAINING_RELEVANCE_FILE -c $SOLR_CLUSTER_ID \
    -x $SOLR_COLLECTION_NAME -n $RANKER_NAME
echo "[unix] ranker=$RANKER_NAME trained..."


echo "[unix] migrateGt.sh script completed successfully. Exiting with status code 0"
exit 0
