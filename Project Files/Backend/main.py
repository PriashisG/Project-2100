import requests
from collections import defaultdict

baseURL = "https://codeforces.com/api/"

def submission_check(handle):
    URL = baseURL + "user.status?handle=" + handle + "&from=1&count=500"
    # geting last 500 submission
    try:
        response = requests.get(URL, timeout=20)
        data = response.json()
    except Exception:
        print("Something went wrong with internet!!!")
        return None

    if data["status"] != "OK":
        print("API error!!!")
        return None
    
    submissions = data["result"]
    submissions.reverse()
    print(f"\nFound last 500 submission of {handle} successfully.\n")

    # analysis the submissions
    attempt_cnt = defaultdict(int)
    ac_problem = {}
    """
        ac_problem = {
            (contestId, index) : {
                "problem_id" : "1234A",
                "rating"     : 800,
                "attempts"   : 3,
                "tags"       : ["math", "number theory"]
            },
            .....
        }
    """
    
    for sub in submissions:
        problem_info = sub.get("problem", {})
        key = str(problem_info.get("contestId")) + problem_info.get("index")
        verdict = sub.get("verdict")
        attempt_cnt[key] += 1
        
        if verdict == "OK":
            ac_problem[key] = {
                "problem_id" : key,
                "rating" : problem_info.get("rating"),
                "attempt" : attempt_cnt[key],
                "tags" : problem_info.get("tags", []),
            }
            
    # print all for checking
    # print()
    # for key, value in ac_problem.items():
    #     print(f"Problem ID : {key}")
    #     print(f"Rating     : {value['rating']}")
    #     print(f"Attempts   : {value['attempt']}")
    #     print(f"Tags       : {value['tags']}")
    #     print()        
    
    print(f"All submission of {handle} is checked successfully.")
    return ac_problem





    
    


def get_other_user_info(rating):
    # checking input rating
    print(f"Main user rating : {rating}")
    low = rating - 200
    high = rating + 200
    print(f"Targeting range : {low} to {high}")
    
    print(f"\nProcessing users with rating {low} to {high}.")
    URL = baseURL + "user.ratedList?activeOnly=true&includeRetired=false"
    response = requests.get(URL)
    data = response.json()
    
    # checking is api working or not 
    if data["status"] != "OK":
        print("API is not working")
        return
    
    low_count = 0
    high_count = 0
    for user in data["result"]:
        user_rating = user.get("rating")
        # handling unrated user
        if user_rating is None:
            continue
        
        # checking low range handle
        if low_count < 50 and user_rating >= low and user_rating <= rating:
            user_handle_name = user['handle']
            print(f"Accessing user = {user_handle_name} ; Rxating = {user_rating}")
            
            # collecting all submisions
            submission = submission_check(user_handle_name)
            # analysis all submissions
            
            low_count += 1
            continue
        
        # checking high range handle
        if high_count < 50 and user_rating > rating and user_rating <= high:
            user_handle_name = user['handle']
            print(f"Accessing user = {user_handle_name} ; Rating = {user_rating}")

            # collecting all submisions
            submission = submission_check(user_handle_name)
            # analysis all submissions
            
            high_count += 1
        
        # breaking condition
        if low_count + high_count == 100:
            break
        
    print(f"\nTotal users found: {low_count + high_count}")


def get_info(handle):
    url = f"{baseURL}user.info?handles={handle}"
    data = requests.get(url).json()

    # checking if id valid or not
    while data["status"] != "OK" :
        print("Error: Not a valid handle!!!\n")
        handle = ask_name()
        url = f"{baseURL}user.info?handles={handle}"
        data = requests.get(url).json()

    user = data["result"][0]
    rating = user.get("rating")
    rank = user.get("rank")
    print("Handle :", user["handle"])
    
    # checking unrated or not
    if rating is None:
        print("Rating : Unrated")
        print("Rank   : None")
    else:
        print("Rating :", rating)
        print("Rank   :", rank)
        return rating
        
        
    

def ask_name() :
    print("Enter a handle name = ", end="")
    handle = input().strip()
    return handle

def closing_msg():
    print("\n\t**** App is closing ****")


def main() :
    print("\t**** CP tracker ****\n")
    handle_name = ask_name()
    handle_rating = get_info(handle_name)
    # checking my submission
    user_submission_data = submission_check(handle_name)
    if user_submission_data is None:
        print("Something went wrong with accessing main_user's submissions!!!")
        closing_msg()
        return
    
    # asking for -200 to 200 rated 100 username
    get_other_user_info(handle_rating)
    
    # closing msg
    closing_msg()
    
    
if __name__ == "__main__":
    main()